#!/bin/bash

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then echo "Please run this script as sudo or root"; exit 1 ; fi

# Version number of Guacamole to install
GUACVERSION="1.0.0"

# Colors to use for output
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Log Location
LOG="/tmp/guacamole_${GUACVERSION}_build.log"

# Database Name
DB="guacamole_db"

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

debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlrootpassword"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysqlrootpassword"

# Ubuntu and Debian have different package names for libjpeg
# Ubuntu and Debian versions have differnet package names for libpng-dev
# Ubuntu 18.04 does not include universe repo by default
source /etc/os-release
if [[ "${NAME}" == "Ubuntu" ]]
then
    JPEGTURBO="libjpeg-turbo8-dev"
    if [[ "${VERSION_ID}" == "18.04" ]]
    then
        sed -i 's/bionic main$/bionic main universe/' /etc/apt/sources.list
    fi
    if [[ "${VERSION_ID}" == "16.04" ]]
    then
        LIBPNG="libpng12-dev"
    else
        LIBPNG="libpng-dev"
    fi
elif [[ "${NAME}" == *"Debian"* ]]
then
    JPEGTURBO="libjpeg62-turbo-dev"
    if [[ "${PRETTY_NAME}" == *"stretch"* ]]
    then
        LIBPNG="libpng-dev"
    else
        LIBPNG="libpng12-dev"
    fi
else
    echo "Unsupported Distro - Ubuntu or Debian Only"
    exit 1
fi

# Update apt so we can search apt-cache for newest tomcat version supported
apt-get -qq update

# Tomcat 8.0.x is End of Life, however Tomcat 7.x is not...
# If Tomcat 8.5.x or newer is available install it, otherwise install Tomcat 7
if [[ $(apt-cache show tomcat8 | egrep "Version: 8.[5-9]" | wc -l) -gt 0 ]]
then
    TOMCAT="tomcat8"
else
    TOMCAT="tomcat7"
fi

# Uncomment to manually force a tomcat version
#TOMCAT=""

# Install features
echo -e "${BLUE}Installing dependencies${NC}"

apt-get -qq -y install build-essential libcairo2-dev ${JPEGTURBO} ${LIBPNG} libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev mysql-server mysql-client mysql-common mysql-utilities libmysql-java ${TOMCAT} freerdp-x11 \
ghostscript wget dpkg-dev
  if [ $? -ne 0 ]; then
        echo -e "${RED}Failed${NC}"
        exit 1
        else
        echo -e "${GREEN}OK${NC}"
    fi

# If apt fails to run completely the rest of this isn't going to work...
if [ $? -ne 0 ]; then
    echo -e "${RED}apt-get failed to install all required dependencies${NC}"
    exit 1
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

# Download Guacamole authentication extensions
wget -q --show-progress -O guacamole-auth-jdbc-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    echo -e "${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    exit 1
fi
echo -e "${GREEN}Downloaded guacamole-auth-jdbc-${GUACVERSION}.tar.gz${NC}"

echo -e "${GREEN}Downloading complete.${NC}"

# Extract Guacamole files
tar -xzf guacamole-server-${GUACVERSION}.tar.gz
tar -xzf guacamole-auth-jdbc-${GUACVERSION}.tar.gz

# Make directories
mkdir -p /etc/guacamole/lib
mkdir -p /etc/guacamole/extensions

# Install guacd
cd guacamole-server-${GUACVERSION}

# Patch leftover for Guacamole Server 0.9.14
#wget -q --show-progress -O ./src/terminal/cd0e48234a079813664052b56c501e854753303a.patch https://github.com/apache/guacamole-server/commit/cd0e48234a079813664052b56c501e854753303a.patch
#if [ $? -ne 0 ]; then
#    echo -e "${RED}Failed to download cd0e48234a079813664052b56c501e854753303a.patch"
#    echo -e "https://github.com/apache/guacamole-server/commit/cd0e48234a079813664052b56c501e854753303a.patch"
#    echo -e "Attempting to proceed without patch...${NC}"
#else
#    patch ./src/terminal/typescript.c ./src/terminal/cd0e48234a079813664052b56c501e854753303a.patch
#fi

# Hack for gcc7
if [[ $(gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}' | grep "^7" | wc -l) -gt 0 ]]
then
    echo -e "${BLUE}Building Guacamole with GCC6...${NC}"
    apt-get -qq -y install gcc-6
    if [ $? -ne 0 ]; then
        echo -e "${RED}apt-get failed to install gcc-6${NC}"
        exit 1
        else
        echo -e "${GREEN}GCC6 Installed${NC}"
    fi
    CC="gcc-6"

else
    echo -e "${BLUE}Building Guacamole with GCC7...${NC}"
    CC="gcc-7"
fi
     echo -e "${BLUE}Configuring...${NC}"
     ./configure --with-init-dir=/etc/init.d  &>> ${LOG}
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed${NC}"
        exit 1
        else
        echo -e "${GREEN}OK${NC}"
    fi
     echo -e "${BLUE}Running Make...${NC}"
    make &>> ${LOG}
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed${NC}"
        exit 1
        else
        echo -e "${GREEN}OK${NC}"
    fi
     echo -e "${BLUE}Running Make Install...${NC}"
     make install &>> ${LOG}
     if [ $? -ne 0 ]; then
        echo -e "${RED}Failed${NC}"
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

# Configure guacamole.properties
echo "mysql-hostname: localhost" >> /etc/guacamole/guacamole.properties
echo "mysql-port: 3306" >> /etc/guacamole/guacamole.properties
echo "mysql-database: ${DB}" >> /etc/guacamole/guacamole.properties
echo "mysql-username: guacamole_user" >> /etc/guacamole/guacamole.properties
echo "mysql-password: ${guacdbuserpassword}" >> /etc/guacamole/guacamole.properties

# restart tomcat
echo -e "${BLUE}Restarting tomcat...${NC}"

service ${TOMCAT} restart
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Create guacamole_db and grant guacamole_user permissions to it

# SQL code
SQLCODE="
create database ${DB};
create user 'guacamole_user'@'localhost' identified by \"${guacdbuserpassword}\";
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
flush privileges;"

# Execute SQL code
echo ${SQLCODE} | mysql -u root -p${mysqlrootpassword}

# Add Guacamole schema to newly created database
echo -e "Adding db tables..."
cat guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/*.sql | mysql -u root -p${mysqlrootpassword} ${DB}
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed${NC}"
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Ensure guacd is started
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

echo -e "${BLUE}Installation Complete\nhttp://localhost:8080/guacamole/\nDefault login guacadmin:guacadmin\nBe sure to change the password.${NC}"
