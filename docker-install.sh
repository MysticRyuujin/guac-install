#!/bin/bash

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then echo "Please run this script as sudo or root"; exit 1 ; fi

# Version number of Guacamole to install
GUACVERSION="1.6.0"

# Initialize variable values
installTOTP=""
installDUO=""

# This is where we'll store persistent data for guacamole
INSTALLFOLDER="/opt/guacamole"

# This is where we'll store persistent data for mysql
MYSQLDATAFOLDER="/opt/mysql"

# Make folders!
mkdir -p ${INSTALLFOLDER}/install_files
mkdir ${INSTALLFOLDER}/extensions
mkdir ${MYSQLDATAFOLDER}

cd ${INSTALLFOLDER}/install_files

# Colors to use for output
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script arguments for non-interactive mode
while [ "$1" != "" ]; do
    case $1 in
        -m | --mysqlpwd )
            shift
            mysqlpwd="$1"
            ;;
        -g | --guacpwd )
            shift
            guacpwd="$1"
            ;;
        -t | --totp )
            installTOTP=true
			;;
        -d | --duo )
            installDUO=true
		
    esac
    shift
done

# Get MySQLroot password and Guacamole User password
if [ -n "$mysqlpwd" ] && [ -n "$guacpwd" ]; then
        mysqlrootpassword=$mysqlpwd
        guacdbuserpassword=$guacpwd
else
    echo
    while true
    do
        read -s -p "Enter a MySQL ROOT Password: " mysqlrootpassword
        echo
        read -s -p "Confirm MySQL ROOT Password: " password2
        echo
        [ "$mysqlrootpassword" = "$password2" ] && break
        echo "Passwords don't match. Please try again."
        echo
    done
    echo
    while true
    do
        read -s -p "Enter a Guacamole User Database Password: " guacdbuserpassword
        echo
        read -s -p "Confirm Guacamole User Database Password: " password2
        echo
        [ "$guacdbuserpassword" = "$password2" ] && break
        echo "Passwords don't match. Please try again."
        echo
    done
    echo
fi

if [[ -z "${installTOTP}" ]]; then
    # Prompt the user if they would like to install TOTP MFA, default of no
    echo -e -n "${CYAN}MFA: Would you like to install TOTP? (y/N): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        installTOTP=true
    else
        installTOTP=false
    fi
fi

if [[ -z "${installDUO}" ]]; then
    # Prompt the user if they would like to install DUO MFA, default of no
    echo -e -n "${CYAN}MFA: Would you like to install DUO? (y/N): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        installDUO=true
    else
        installDUO=false
    fi
fi

# We can't install TOTP and Duo at the same time...
if [[ "${installTOTP}" = true ]] && [ "${installDuo}" = true ]; then
    echo -e "${RED}MFA: The script does not support installing TOTP and Duo at the same time.${NC}" 1>&2
    exit 1
fi
echo

# Update install wget if it's missing
apt-get update
apt-get -y install wget

# Check if mysql client already installed
if [ -x "$(command -v mysql)" ]; then
    echo "mysql detected!"
else
    # Install mysql-client
    apt-get -y install default-mysql-client
    if [ $? -ne 0 ]; then
        echo "Failed to install apt prerequisites: default-mysql-client"
        echo "Try manually isntalling this prerequisites and try again"
        exit
    fi
fi

# Check if docker already installed
if [ -x "$(command -v docker)" ]; then
    echo "docker detected!"
else
    echo "Installing docker"
    # Try to install docker from the official repo
    apt-get -y install docker-ce docker-ce-cli containerd.io
    if [ $? -ne 0 ]; then
        echo "Failed to install docker via official apt repo"
       echo "Trying to install docker from https://get.docker.com"
        wget -O get-docker.sh https://get.docker.com
        chmod +x ./get-docker.sh
        ./get-docker.sh
        if [ $? -ne 0 ]; then
            echo "Failed to install docker from https://get.docker.com"
            exit
        fi
    fi
fi

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACVERSION}"

# Download Guacamole authentication extensions
wget -O guacamole-auth-jdbc-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    echo "${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    exit
fi

tar -xzf guacamole-auth-jdbc-${GUACVERSION}.tar.gz


# Download and install TOTP
if [ "${installTOTP}" = true ]; then
    wget -q --show-progress -O guacamole-auth-totp-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-totp-${GUACVERSION}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download guacamole-auth-totp-${GUACVERSION}.tar.gz" 1>&2
        echo -e "${SERVER}/binary/guacamole-auth-totp-${GUACVERSION}.tar.gz"
        exit 1
    else
        echo -e "${GREEN}Downloaded guacamole-auth-totp-${GUACVERSION}.tar.gz${NC}"
        tar -xzf guacamole-auth-totp-${GUACVERSION}.tar.gz
        echo -e "${BLUE}Moving guacamole-auth-totp-${GUACVERSION}.jar (${INSTALLFOLDER}/extensions/)...${NC}"
        cp -f guacamole-auth-totp-${GUACVERSION}/guacamole-auth-totp-${GUACVERSION}.jar ${INSTALLFOLDER}/extensions/
        echo
    fi
fi


# Download and install DUO

if [ "${installDUO}" = true ]; then
    wget -q --show-progress -O guacamole-auth-duo-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-duo-${GUACVERSION}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download guacamole-auth-duo-${GUACVERSION}.tar.gz" 1>&2
        echo -e "${SERVER}/binary/guacamole-auth-duo-${GUACVERSION}.tar.gz"
        exit 1
    else
        echo -e "${GREEN}Downloaded guacamole-auth-duo-${GUACVERSION}.tar.gz${NC}"
        tar -xzf guacamole-auth-duo-${GUACVERSION}.tar.gz
        echo -e "${BLUE}Moving guacamole-auth-duo-${GUACVERSION}.jar (${INSTALLFOLDER}/extensions/)...${NC}"
        cp -f guacamole-auth-duo-${GUACVERSION}/guacamole-auth-duo-${GUACVERSION}.jar ${INSTALLFOLDER}/extensions/
        echo
    fi
fi


# Configure guacamole.properties
rm -f ${INSTALLFOLDER}/guacamole.properties
touch ${INSTALLFOLDER}/guacamole.properties
echo "mysql-hostname: 127.0.0.1" >> ${INSTALLFOLDER}/guacamole.properties
echo "mysql-port: 3306" >> ${INSTALLFOLDER}/guacamole.properties
echo "mysql-database: guacamole_db" >> ${INSTALLFOLDER}/guacamole.properties
echo "mysql-username: guacamole_user" >> ${INSTALLFOLDER}/guacamole.properties
echo "mysql-password: $guacdbuserpassword" >> ${INSTALLFOLDER}/guacamole.properties

# Output Duo configuration settings but comment them out for now
if [ "${installDUO}" = true ]; then
    echo "# duo-api-hostname: " >> ${INSTALLFOLDER}/guacamole.properties
    echo "# duo-integration-key: " >> ${INSTALLFOLDER}/guacamole.properties
    echo "# duo-secret-key: " >> ${INSTALLFOLDER}/guacamole.properties
    echo "# duo-application-key: " >> ${INSTALLFOLDER}/guacamole.properties
    echo -e "${YELLOW}Duo is installed, it will need to be configured via guacamole.properties at ${INSTALLFOLDER}/guacamole.properties${NC}"
fi


# Start MySQL
docker run --restart=always --detach --name=mysql -v ${MYSQLDATAFOLDER}:/var/lib/mysql --env="MYSQL_ROOT_PASSWORD=$mysqlrootpassword" --publish 3306:3306 healthcheck/mysql --default-authentication-plugin=mysql_native_password

# Wait for the MySQL Health Check equal "healthy"
echo "Waiting for MySQL to be healthy"
until [ "$(/usr/bin/docker inspect -f {{.State.Health.Status}} mysql)" == "healthy" ]; do
    sleep 0.1;
done;

# Create the Guacamole database and the user account
# SQL Code
SQLCODE="
create database guacamole_db;
create user 'guacamole_user'@'%' identified by '$guacdbuserpassword';
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'%';
flush privileges;"

# Execute SQL Code
echo $SQLCODE | mysql -h 127.0.0.1 -P 3306 -u root -p$mysqlrootpassword

cat guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword -h 127.0.0.1 -P 3306 guacamole_db

docker run --restart=always --name guacd --detach guacamole/guacd:${GUACVERSION}
docker run --restart=always --name guacamole --detach --link mysql:mysql --link guacd:guacd -v ${INSTALLFOLDER}:/etc/guacamole -e MYSQL_HOSTNAME=127.0.0.1 -e MYSQL_DATABASE=guacamole_db -e MYSQL_USER=guacamole_user -e MYSQL_PASSWORD=$guacdbuserpassword -e GUACAMOLE_HOME=/etc/guacamole -p 8080:8080 guacamole/guacamole:${GUACVERSION}

# Done
echo
echo -e "${YELLOW}\nInstallation Complete\n- Visit: http://localhost:8080/guacamole/\n- Default login (username/password): guacadmin/guacadmin\n***Be sure to change the password***."
if [ "${installDUO}" = true ]; then
    echo -e "${YELLOW}\nDon't forget to configure Duo in guacamole.properties at ${INSTALLFOLDER}/. You will not be able to login otherwise.\nhttps://guacamole.apache.org/doc/${GUACVERSION}/gug/duo-auth.html${NC}"
fi
