#!/bin/bash

# Version numbers of Guacamole and MySQL Connector/J to download
VERSION="0.9.13"
MCJVERSION="5.1.44"

# Update apt so we can search apt-cache for newest tomcat version supported
apt update

# tomcat8 seems to be broken, tomcat7 and tomcat6 should work
if [ $(apt-cache search "^tomcat7$" | wc -l) -gt 0 ]; then
    TOMCAT="tomcat7"
else
    TOMCAT="tomcat6"
fi

# If you want to force a specific tomcat install and not go with the newest just set it here and uncomment:
#TOMCAT=""

# Get MySQL root password and Guacamole User password
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

debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlrootpassword"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysqlrootpassword"

# Ubuntu and Debian have different names of the libjpeg-turbo library for some reason...
source /etc/lsb-release

if [ $DISTRIB_ID == "Ubuntu" ]
then
    JPEGTURBO="libjpeg-turbo8-dev"
else
    JPEGTURBO="libjpeg62-turbo-dev"
fi

# Ubuntu 16.10 has a different name for libpng12-dev for some reason...
if [ $DISTRIB_RELEASE == "16.10" ]
then
    LIBPNG="libpng-dev"
else
    LIBPNG="libpng12-dev"
fi

# Install features
apt -y install build-essential libcairo2-dev ${JPEGTURBO} ${LIBPNG} libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev mysql-server mysql-client mysql-common mysql-utilities ${TOMCAT} freerdp ghostscript jq wget curl dpkg-dev

# If apt fails to run completely the rest of this isn't going to work...
if [ $? != 0 ]; then
    echo "apt failed to install all required dependencies"
    exit
fi

# Add GUACAMOLE_HOME to $TOMCAT ENV
echo "" >> /etc/default/${TOMCAT}
echo "# GUACAMOLE ENV VARIABLE" >> /etc/default/${TOMCAT}
echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/${TOMCAT}

# Set SERVER to be the preferred download server from the Apache CDN
SERVER=$(curl -s 'https://www.apache.org/dyn/closer.cgi?action=download&filename=guacamole' | jq --raw-output '.preferred|rtrimstr("/")')

# Download Guacamole Server
wget ${SERVER}${VERSION}-incubating/source/guacamole-server-${VERSION}-incubating.tar.gz
if [ ! -f ./guacamole-server-${VERSION}-incubating.tar.gz ]; then
    echo "Failed to download guacamole-server-${VERSION}-incubating.tar.gz"
    echo "${SERVER}/incubator/guacamole/${VERSION}-incubating/source/guacamole-server-${VERSION}-incubating.tar.gz"
    exit
fi

# Download Guacamole Client
wget ${SERVER}${VERSION}-incubating/binary/guacamole-${VERSION}-incubating.war
if [ ! -f ./guacamole-${VERSION}-incubating.war ]; then
    echo "Failed to download guacamole-${VERSION}-incubating.war"
    echo "${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-${VERSION}-incubating.war"
    exit
fi

# Download Guacamole authentication extensions
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
if [ ! -f ./guacamole-auth-jdbc-${VERSION}-incubating.tar.gz ]; then
    echo "Failed to download guacamole-auth-jdbc-${VERSION}-incubating.tar.gz"
    echo "${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz"
    exit
fi

# Download MySQL Connector-J
wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz
if [ ! -f ./mysql-connector-java-${MCJVERSION}.tar.gz ]; then
    echo "Failed to download guacamole-server-${VERSION}-incubating.tar.gz"
    echo "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz"
    exit
fi

# Extract Guacamole files
tar -xzf guacamole-server-${VERSION}-incubating.tar.gz
tar -xzf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xzf mysql-connector-java-${MCJVERSION}.tar.gz

# Make directories
mkdir -p /etc/guacamole/lib
mkdir -p /etc/guacamole/extensions

# Install guacd
cd guacamole-server-${VERSION}-incubating
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
systemctl enable guacd
cd ..

# Get build-folder
BUILD_FOLDER=$(dpkg-architecture -qDEB_BUILD_GNU_TYPE)

# Move files to correct locations
mv guacamole-${VERSION}-incubating.war /etc/guacamole/guacamole.war
ln -s /etc/guacamole/guacamole.war /var/lib/${TOMCAT}/webapps/
ln -s /usr/local/lib/freerdp/guac*.so /usr/lib/${BUILD_FOLDER}/freerdp/
cp mysql-connector-java-${MCJVERSION}/mysql-connector-java-${MCJVERSION}-bin.jar /etc/guacamole/lib/
cp guacamole-auth-jdbc-${VERSION}-incubating/mysql/guacamole-auth-jdbc-mysql-${VERSION}-incubating.jar /etc/guacamole/extensions/

# Configure guacamole.properties
echo "mysql-hostname: localhost" >> /etc/guacamole/guacamole.properties
echo "mysql-port: 3306" >> /etc/guacamole/guacamole.properties
echo "mysql-database: guacamole_db" >> /etc/guacamole/guacamole.properties
echo "mysql-username: guacamole_user" >> /etc/guacamole/guacamole.properties
echo "mysql-password: $guacdbuserpassword" >> /etc/guacamole/guacamole.properties
rm -rf /usr/share/${TOMCAT}/.guacamole
ln -s /etc/guacamole /usr/share/${TOMCAT}/.guacamole

# restart tomcat
service ${TOMCAT} restart

# Create guacamole_db and grant guacamole_user permissions to it

# SQL code
SQLCODE="
create database guacamole_db;
create user 'guacamole_user'@'localhost' identified by \"$guacdbuserpassword\";
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
flush privileges;"

# Execute SQL code
echo $SQLCODE | mysql -u root -p$mysqlrootpassword

# Add Guacamole schema to newly created database
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword guacamole_db

# Cleanup
rm -rf guacamole-*
rm -rf mysql-connector-java-${MCJVERSION}*

echo -e "Installation Complete\nhttp://localhost:8080/guacamole/\nDefault login guacadmin:guacadmin\nBe sure to change the password."
