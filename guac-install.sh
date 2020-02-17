#!/bin/bash

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then echo "Please run this script as sudo or root"; exit 1 ; fi

# Version number of Guacamole to install
GUACVERSION="1.1.0"

# Colors to use for output
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log Location
LOG="/tmp/guacamole_${GUACVERSION}_build.log"

# Initialize variable values
installTOTP=""
installDuo=""

installMySQL=""
mysqlHost=""
mysqlPort=""
mysqlRootPwd=""

guacDb=""
guacUser=""
guacPwd=""

PROMPT=""

# Get script arguments for non-interactive mode
while [ "$1" != "" ]; do
    case $1 in
        # Install MySQL selection
        -i | --installmysql )
            installMySQL=true
            ;;
        -n | --nomysql )
            installMySQL=false
            ;;

        # MySQL server/root information
        -h | --mysqlhost )
            shift
            mysqlHost="$1"
            ;;
        -p | --mysqlport )
            shift
            mysqlPort="$1"
            ;;
        -r | --mysqlpwd )
            shift
            mysqlRootPwd="$1"
            ;;

        # Guac database/user information
        -db | --guacdb )
            shift
            guacDb="$1"
            ;;
        -gu | --guacuser )
            shift
            guacUser="$1"
            ;;
        -gp | --guacpwd )
            shift
            guacpwd="$1"
            ;;

        # MFA selection
        -t | --totp )
            installTOTP=true
            ;;
        -d | --duo )
            installDuo=true
    esac
    shift
done

# We can't install TOTP and Duo at the same time...
if [[ ! -z $installTOTP ] && [ ! -z $installDuo ]]; then
    echo "The script does not support installing TOTP and Duo at the same time."
    exit 1
fi

if [[ -z $installTOTP ] && [ -z $installDuo ]]; then
    # Prompt the user if they would like to install TOTP MFA, default of no
    echo -e -n "${CYAN}(!)${NC} Would you like to install TOTP? (y/N): "
    read PROMPT
    if [[ $PROMPT =~ ^[Yy]$ ]]; then installTOTP=true; else installTOTP=false; fi
fi

if [[ -z $installDuo ] && [ -z $installTOTP ]]; then
    # Prompt the user if they would like to install Duo MFA, default of no
    echo -e -n "${CYAN}(!)${NC} Would you like to install Duo (configuration values must be set after install in guacamole.properties)? (y/N): "
    read PROMPT
    if [[ $PROMPT =~ ^[Yy]$ ]]; then installDuo=true; else installDuo=false; fi
fi

if [[ -z $installMySQL ]]; then
    # Prompt the user to see if they would like to install MySQL, default of yes
    echo -e -n "${CYAN}(!)${NC} Would you like to install MySQL? (Y/n): "
    read PROMPT
    if [[ $PROMPT =~ ^[Nn]$ ]]; then installMySQL=false; else installMySQL=true; fi
fi

if [ "$installMySQL" = false ]; then
    # We need to get additional values
    read -p "Enter MySQL server hostname or IP: " mysqlHost
    read -p "Enter MySQL server port [3306]: " mysqlPort
    read -p "Enter Guacamole database name [guacamole_db]: " guacDb
    read -p "Enter Guacamole user [guacamole_user]: " guacUser
fi

# Get MySQL Root password and Guacamole User password
echo
while true
do
    read -s -p "Enter a MySQL ROOT Password: " mysqlRootPwd
    echo
    read -s -p "Confirm MySQL ROOT Password: " PROMPT2
    echo
    [ "$mysqlRootPwd" = "$PROMPT2" ] && break
    echo "Passwords don't match. Please try again."
    echo
done
echo
while true
do
    read -s -p "Enter a Guacamole User Database Password: " guacPwd
    echo
    read -s -p "Confirm Guacamole User Database Password: " PROMPT2
    echo
    [ "$guacPwd" = "$PROMPT2" ] && break
    echo "Passwords don't match. Please try again."
    echo
done
echo

if [ "$installMySQL" = true ]; then
    # Seed MySQL install values
    debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlRootPwd"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysqlRootPwd"
fi

# Checking if mysql host given
if [ -z "$mysqlHost" ]; then
    mysqlHost="localhost"
fi

# Checking if mysql port given
if [ -z "$mysqlPort" ]; then
    mysqlPort="3306"
fi

# Checking if mysql user given
if [ -z "$guacUser" ]; then
    guacUser="guacamole_user"
fi

# Checking if database name given
if [ -z "$guacDb" ]; then
    guacDb="guacamole_db"
fi

# Ubuntu and Debian have different package names for libjpeg
# Ubuntu and Debian versions have differnet package names for libpng-dev
# Ubuntu > 18.04 does not include universe repo by default
source /etc/os-release
if [[ "${NAME}" == "Ubuntu" ]]; then
    # Add the "Universe" repo, don't update
    add-apt-repository -yn universe
    JPEGTURBO="libjpeg-turbo8-dev"
    if [[ "${VERSION_ID}" == "16.04" ]]; then
        LIBPNG="libpng12-dev"
    else
        LIBPNG="libpng-dev"
    fi
    if [[ "${VERSION_ID}" == "19.10" ]]; then
        JAVALIB="libmariadb-java"
    else
        JAVALIB="libmysql-java"
    fi
elif [[ "${NAME}" == *"Debian"* ]] || [[ "${NAME}" == *"Raspbian GNU/Linux"* ]]; then
    JPEGTURBO="libjpeg62-turbo-dev"
    JAVALIB="libmysql-java"
    if [[ "${PRETTY_NAME}" == *"stretch"* ]] || [[ "${PRETTY_NAME}" == *"buster"* ]]; then
        LIBPNG="libpng-dev"
    else
        LIBPNG="libpng12-dev"
    fi
else
    echo "Unsupported Distro - Ubuntu, Debian, or Raspbian Only"
    exit 1
fi

# Update apt so we can search apt-cache for newest tomcat version supported
apt-get -qq update

# Tomcat 8.0.x is End of Life, however Tomcat 7.x is not...
# If Tomcat 8.5.x or newer is available install it, otherwise install Tomcat 7
# I have not testing with Tomcat9...
if [[ $(apt-cache show tomcat8 | egrep "Version: 8.[5-9]" | wc -l) -gt 0 ]]; then
    TOMCAT="tomcat8"
else
    TOMCAT="tomcat7"
fi

MYSQL=""
if [ "$installMySQL" = true ]; then
    if [ -z $(command -v mysql) ]; then
        MYSQL="mysql-server mysql-client mysql-common mysql-utilities"
    fi
else
    MYSQL="mysql-client"
fi

# Uncomment to manually force a tomcat version
#TOMCAT=""

# Install features
echo -e "${BLUE}Installing dependencies. This might take a few minutes...${NC}"

export DEBIAN_FRONTEND=noninteractive

apt-get -y install build-essential libcairo2-dev ${JPEGTURBO} ${LIBPNG} libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev ${MYSQL} ${JAVALIB} ${TOMCAT} freerdp2-x11 libtool-bin libwebsockets-dev \
ghostscript wget dpkg-dev &>> ${LOG}

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed. See ${LOG}${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACVERSION}"
echo -e "${BLUE}Downloading Files...${NC}"

# Download Guacamole Server
wget -q --show-progress -O guacamole-server-${GUACVERSION}.tar.gz ${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download guacamole-server-${GUACVERSION}.tar.gz"
    echo -e "${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz${NC}"
    exit 1
fi
echo -e "${GREEN}Downloaded guacamole-server-${GUACVERSION}.tar.gz${NC}"

# Download Guacamole Client
wget -q --show-progress -O guacamole-${GUACVERSION}.war ${SERVER}/binary/guacamole-${GUACVERSION}.war
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download guacamole-${GUACVERSION}.war"
    echo -e "${SERVER}/binary/guacamole-${GUACVERSION}.war${NC}"
    exit 1
fi
echo -e "${GREEN}Downloaded guacamole-${GUACVERSION}.war${NC}"

# Download Guacamole authentication extensions (Database)
wget -q --show-progress -O guacamole-auth-jdbc-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    echo -e "${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    exit 1
fi
echo -e "${GREEN}Downloaded guacamole-auth-jdbc-${GUACVERSION}.tar.gz${NC}"

# Download Guacamole authentication extensions
if [ "$installTOTP" = true ]; then
    # TOTP
	wget -q --show-progress -O guacamole-auth-totp-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-totp-${GUACVERSION}.tar.gz
	if [ $? -ne 0 ]; then
    	echo -e "${RED}Failed to download guacamole-auth-totp-${GUACVERSION}.tar.gz"
    	echo -e "${SERVER}/binary/guacamole-auth-totp-${GUACVERSION}.tar.gz"
    	exit 1
	fi
	echo -e "${GREEN}Downloaded guacamole-auth-totp-${GUACVERSION}.tar.gz${NC}"

	echo -e "${GREEN}Downloading complete.${NC}"
	tar -xzf guacamole-auth-totp-${GUACVERSION}.tar.gz
fi
if [ "$installDuo" = true ]; then
    # Duo
	wget -q --show-progress -O guacamole-auth-duo-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-duo-${GUACVERSION}.tar.gz
	if [ $? -ne 0 ]; then
    	echo -e "${RED}Failed to download guacamole-auth-duo-${GUACVERSION}.tar.gz"
    	echo -e "${SERVER}/binary/guacamole-auth-duo-${GUACVERSION}.tar.gz"
    	exit 1
	fi
	echo -e "${GREEN}Downloaded guacamole-auth-duo-${GUACVERSION}.tar.gz${NC}"

	echo -e "${GREEN}Downloading complete.${NC}"
	tar -xzf guacamole-auth-duo-${GUACVERSION}.tar.gz
fi

# Extract Guacamole files
tar -xzf guacamole-server-${GUACVERSION}.tar.gz
tar -xzf guacamole-auth-jdbc-${GUACVERSION}.tar.gz

# Make directories
mkdir -p /etc/guacamole/lib
mkdir -p /etc/guacamole/extensions

# Install guacd
cd guacamole-server-${GUACVERSION}

echo -e "${BLUE}Building Guacamole with GCC $(gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}') ${NC}"

echo -e "${BLUE}Configuring. This might take a minute...${NC}"
./configure --with-init-dir=/etc/init.d  &>> ${LOG}
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed. See ${LOG}${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

echo -e "${BLUE}Running Make. This might take a few minutes...${NC}"
make &>> ${LOG}
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed. See ${LOG}${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

echo -e "${BLUE}Running Make Install...${NC}"
make install &>> ${LOG}
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed. See ${LOG}${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

ldconfig
systemctl enable guacd
cd ..

# Get build-folder
BUILD_FOLDER=$(dpkg-architecture -qDEB_BUILD_GNU_TYPE)

# Move files to correct locations
mv guacamole-${GUACVERSION}.war /etc/guacamole/guacamole.war
ln -s /etc/guacamole/guacamole.war /var/lib/${TOMCAT}/webapps/
ln -s /usr/local/lib/freerdp/guac*.so /usr/lib/${BUILD_FOLDER}/freerdp/
ln -s /usr/share/java/mysql-connector-java.jar /etc/guacamole/lib/
cp guacamole-auth-jdbc-${GUACVERSION}/mysql/guacamole-auth-jdbc-mysql-${GUACVERSION}.jar /etc/guacamole/extensions/

if [ "$installTOTP" = true ]; then
	cp guacamole-auth-totp-${GUACVERSION}/guacamole-auth-totp-${GUACVERSION}.jar /etc/guacamole/extensions/
fi
if [ "$installDuo" = true ]; then
	cp guacamole-auth-duo-${GUACVERSION}/guacamole-auth-duo-${GUACVERSION}.jar /etc/guacamole/extensions/
fi

# Configure guacamole.properties
rm -f /etc/guacamole/guacamole.properties
touch /etc/guacamole/guacamole.properties
echo "mysql-hostname: ${mysqlHost}" >> /etc/guacamole/guacamole.properties
echo "mysql-port: ${mysqlPort}" >> /etc/guacamole/guacamole.properties
echo "mysql-database: ${guacDb}" >> /etc/guacamole/guacamole.properties
echo "mysql-username: ${guacUser}" >> /etc/guacamole/guacamole.properties
echo "mysql-password: ${guacPwd}" >> /etc/guacamole/guacamole.properties

# Output Duo configuration settings but comment them out for now
echo "# duo-api-hostname: " >> /etc/guacamole/guacamole.properties
echo "# duo-integration-key: " >> /etc/guacamole/guacamole.properties
echo "# duo-secret-key: " >> /etc/guacamole/guacamole.properties
echo "# duo-application-key: " >> /etc/guacamole/guacamole.properties
if [ "$installDuo" = true ]; then
    echo -e "${YELLOW}Duo is installed, it will need to be configured via guacamole.properties!${NC}"
fi

# restart tomcat
echo -e "${BLUE}Restarting tomcat...${NC}"

service ${TOMCAT} restart
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Create $guacDb and grant $guacUser permissions to it

# SQL code
guacUserHost="localhost"

if [[ "$mysqlHost" != "localhost" ]]; then
    guacUserHost="%"
    echo -e "${YELLOW}MySQL Guacamole user is set to accept login from any host, please change this for security reasons if possible.${NC}"
fi

SQLCODE="
create database ${guacDb};
create user if not exists '${guacUser}'@'${guacUserHost}' identified by \"${guacPwd}\";
GRANT SELECT,INSERT,UPDATE,DELETE ON ${guacDb}.* TO '${guacUser}'@'${guacUserHost}';
flush privileges;"

export MYSQL_PWD=${mysqlRootPwd}

# Execute SQL code
echo ${SQLCODE} | mysql -u root -h ${mysqlHost} -P ${mysqlPort}

# Add Guacamole schema to newly created database
echo -e "Adding db tables..."
cat guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/*.sql | mysql -u root -D ${guacDb} -h ${mysqlHost} -P ${mysqlPort}
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Ensure guacd is started
echo -e "${BLUE}Starting guacamole...${NC}"
service guacd start

# Cleanup
echo -e "${BLUE}Cleanup install files...${NC}"

rm -rf guacamole-*
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
unset MYSQL_PWD

echo -e "${BLUE}Installation Complete\nhttp://localhost:8080/guacamole/\nDefault login guacadmin:guacadmin\nBe sure to change the password.${NC}"

if [[ ! -z $installDuo ]]; then
    echo -e "${BLUE}Don't forget to configure Duo in guacamole.properties\nhttps://guacamole.apache.org/doc/${GUACVERSION}/gug/duo-auth.html${NC}"
fi
