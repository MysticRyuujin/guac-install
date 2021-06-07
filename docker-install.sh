#!/bin/bash

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then echo "Please run this script as sudo or root"; exit 1 ; fi

# Version number of Guacamole to install
GUACVERSION="1.3.0"

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
    esac
    shift
done

# Get MySQL root password and Guacamole User password
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

# Install Stuff
apt-get update

# Install mysql-client and wget if they don't already have it
apt-get -y install default-mysql-client wget
if [ $? -ne 0 ]; then
    echo "Failed to install apt prerequisites: default-mysql-client wget"
    echo "Try manually isntalling these prerequisites and try again"
    exit
fi

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
    rm ./get-docker.sh
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

# Start MySQL
docker run --restart=always --detach --name=mysql --env="MYSQL_ROOT_PASSWORD=$mysqlrootpassword" --publish 3306:3306 healthcheck/mysql

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

docker run --restart=always --name guacd --detach guacamole/guacd
docker run --restart=always --name guacamole --detach --link mysql:mysql --link guacd:guacd -e MYSQL_HOSTNAME=127.0.0.1 -e MYSQL_DATABASE=guacamole_db -e MYSQL_USER=guacamole_user -e MYSQL_PASSWORD=$guacdbuserpassword -p 8080:8080 guacamole/guacamole

# Cleanup
echo -e "${BLUE}Cleanup install files...${NC}"
rm -rf guacamole-auth-jdbc-${GUACVERSION}*
echo

# Done
echo -e "Installation Complete\n- Visit: http://localhost:8080/guacamole/\n- Default login (username/password): guacadmin/guacadmin\n***Be sure to change the password***."
