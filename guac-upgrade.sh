#!/bin/bash

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then echo "Please run this script as sudo or root"; exit 1 ; fi

# Version number of Guacamole to install
GUACVERSION="1.5.3"

# Colors to use for output
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Try to get host and database from /etc/guacamole/guacamole.properties
mysqlHost=$(grep -oP 'mysql-hostname:\K.*' /etc/guacamole/guacamole.properties | awk '{print $1}')
mysqlPort=$(grep -oP 'mysql-port:\K.*' /etc/guacamole/guacamole.properties | awk '{print $1}')
guacDb=$(grep -oP 'mysql-database:\K.*' /etc/guacamole/guacamole.properties | awk '{print $1}')

# Get script arguments for non-interactive mode
while [ "$1" != "" ]; do
    case $1 in
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
    esac
    shift
done

# Get MySQL host
if [ -z "$mysqlHost" ]; then
    read -p "Enter MySQL Host [localhost]: " mysqlHost
    echo
    if [ -z "$mysqlHost" ]; then
        mysqlHost="localhost"
    fi
fi

# Get MySQL port
if [ -z "$mysqlPort" ]; then
    read -p "Enter MySQL Port [3306]: " mysqlPort
    echo
    if [ -z "$mysqlPort" ]; then
        mysqlPort="3306"
    fi
fi

if [ -n "$mysqlRootPwd" ]; then
    export MYSQL_PWD=${mysqlRootPwd}
    mysql -u root -D ${guacDb} -h ${mysqlHost} -P ${mysqlPort} -e"quit" || exit 1
else
    # Get MySQL root password
    echo
    while true
    do
        read -s -p "Enter MySQL ROOT Password: " mysqlRootPwd
        export MYSQL_PWD=${mysqlRootPwd}
        echo
        mysql -u root -D ${guacDb} -h ${mysqlHost} -P ${mysqlPort} -e"quit" && break
        echo
    done
    echo
fi

# Get Tomcat Version
TOMCAT=$(ls /etc/ | grep tomcat)

# Get Current Guacamole Version
OLDVERSION=$(grep -oP 'Guacamole.API_VERSION = "\K[0-9\.]+' /var/lib/${TOMCAT}/webapps/guacamole/guacamole-common-js/modules/Version.js)

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACVERSION}"

# Stop tomcat and guac
service ${TOMCAT} stop
service guacd stop

# Update apt so we can search apt-cache
apt-get -qq update

# Install additional packages if they do not exist yet
apt-get -y install freerdp2-dev freerdp2-x11 libtool-bin libwebsockets-dev libavformat-dev

# Download Guacamole server
wget -q --show-progress -O guacamole-server-${GUACVERSION}.tar.gz ${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-server-${GUACVERSION}.tar.gz"
    echo "${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz"
    exit
else
    tar -xzf guacamole-server-${GUACVERSION}.tar.gz
fi

# Download Guacamole client
wget -q --show-progress -O guacamole-${GUACVERSION}.war ${SERVER}/binary/guacamole-${GUACVERSION}.war
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-${GUACVERSION}.war"
    echo "${SERVER}/binary/guacamole-${GUACVERSION}.war"
    exit
fi

# Download SQL components
wget -q --show-progress -O guacamole-auth-jdbc-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    echo "${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    exit
else
    tar -xzf guacamole-auth-jdbc-${GUACVERSION}.tar.gz
    rm /etc/guacamole/extensions/guacamole-auth-jdbc-*.jar
    cp guacamole-auth-jdbc-${GUACVERSION}/mysql/guacamole-auth-jdbc-mysql-${GUACVERSION}.jar /etc/guacamole/extensions/
fi

# Upgrade Guacamole Server
cd guacamole-server-${GUACVERSION}
./configure --with-systemd-dir=/etc/systemd/system
if [ $? -ne 0 ]; then
    echo "Failed to configure guacamole-server"
    echo "Trying again with --enable-allow-freerdp-snapshots"
    ./configure --with-systemd-dir=/etc/systemd/system --enable-allow-freerdp-snapshots
    if [ $? -ne 0 ]; then
        echo "Failed to configure guacamole-server - again"
        exit
    fi
fi
make
make install

ldconfig
systemctl enable guacd
cd ..

# Upgrade Guacamole Client
mv guacamole-${GUACVERSION}.war /etc/guacamole/guacamole.war

# Get list of SQL Upgrade Files
UPGRADEFILES=($(ls -1 guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/upgrade/ | sort -V))

# Compare SQL Upgrage Files against old version, apply upgrades as needed
for FILE in ${UPGRADEFILES[@]}
do
    FILEVERSION=$(echo ${FILE} | grep -oP 'upgrade-pre-\K[0-9\.]+(?=\.)')
    if [[ $(echo -e "${FILEVERSION}\n${OLDVERSION}" | sort -V | head -n1) == ${OLDVERSION} && ${FILEVERSION} != ${OLDVERSION} ]]; then
        echo "Patching ${guacDb} with ${FILE}"
        mysql -u root -D ${guacDb} -h ${mysqlHost} -P ${mysqlPort} < guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/upgrade/${FILE}
    fi
done

# Check for either TOTP or Duo extensions and ugprade if found
for file in /etc/guacamole/extensions/guacamole-auth-totp*.jar; do
    if [[ -f $file ]]; then
        # Upgrade TOTP
        echo -e "${BLUE}TOTP extension was found, upgrading...${NC}"
        rm /etc/guacamole/extensions/guacamole-auth-totp*.jar
        wget -q --show-progress -O guacamole-auth-totp-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-totp-${GUACVERSION}.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to download guacamole-auth-totp-${GUACVERSION}.tar.gz"
            echo -e "${SERVER}/binary/guacamole-auth-totp-${GUACVERSION}.tar.gz"
            exit 1
        fi
        echo -e "${GREEN}Downloaded guacamole-auth-totp-${GUACVERSION}.tar.gz${NC}"
        tar -xzf guacamole-auth-totp-${GUACVERSION}.tar.gz
        cp guacamole-auth-totp-${GUACVERSION}/guacamole-auth-totp-${GUACVERSION}.jar /etc/guacamole/extensions/
        echo -e "${GREEN}TOTP copied to extensions.${NC}"
        break
    fi
done

for file in /etc/guacamole/extensions/guacamole-auth-duo*.jar; do
    if [[ -f $file ]]; then
        # Upgrade Duo
        echo -e "${BLUE}Duo extension was found, upgrading...${NC}"
        rm /etc/guacamole/extensions/guacamole-auth-duo*.jar
        wget -q --show-progress -O guacamole-auth-duo-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-duo-${GUACVERSION}.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to download guacamole-auth-duo-${GUACVERSION}.tar.gz"
            echo -e "${SERVER}/binary/guacamole-auth-duo-${GUACVERSION}.tar.gz"
            exit 1
        fi
        echo -e "${GREEN}Downloaded guacamole-auth-duo-${GUACVERSION}.tar.gz${NC}"
        tar -xzf guacamole-auth-duo-${GUACVERSION}.tar.gz
        cp guacamole-auth-duo-${GUACVERSION}/guacamole-auth-duo-${GUACVERSION}.jar /etc/guacamole/extensions/
        echo -e "${GREEN}Duo copied to extensions.${NC}"

        break
    fi
done

# Fix for #196
mkdir -p /usr/sbin/.config/freerdp
chown daemon:daemon /usr/sbin/.config/freerdp

# Fix for #197
mkdir -p /var/guacamole
chown daemon:daemon /var/guacamole

# Start tomcat and Guacamole
echo -e "${BLUE}Starting tomcat and guacamole...${NC}"
service ${TOMCAT} start
service guacd start

# Cleanup
rm -rf guacamole*
unset MYSQL_PWD
