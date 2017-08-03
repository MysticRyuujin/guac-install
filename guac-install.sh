#!/bin/bash

# Version Numbers of Guacamole and MySQL Connection/J to download
VERSION="0.9.13"
MCJVERSION="5.1.43"

# Update apt so we can search apt-cache for newest tomcat version supported
apt-get update

# tomcat8 is newest, tomcat7 and tomcat6 should work too
if [ $(apt-cache search "^tomcat8$" | wc -l) -gt 0 ]; then
    TOMCAT="tomcat8"
elif [ $(apt-cache search "^tomcat7$" | wc -l) -gt 0 ]; then
    TOMCAT="tomcat7"
else
    TOMCAT="tomcat6"
fi

# If you want to force a specific tomcat install and not go with the newest just set it here and uncomment:
#TOMCAT=""

# Grab a password for MySQL Root
read -s -p "Enter the password that will be used for MySQL Root: " mysqlrootpassword
debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlrootpassword"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysqlrootpassword"
echo

# Grab a password for Guacamole Database User Account
read -s -p "Enter the password that will be used for the Guacamole database: " guacdbuserpassword
echo

# Ubuntu and Debian have different names of the libjpeg-turbo library for some reason...
if [ `egrep -c "ID=ubuntu" /etc/os-release` -gt 0 ]
then
    JPEGTURBO="libjpeg-turbo8-dev"
else
    JPEGTURBO="libjpeg62-turbo-dev"
fi

# Get architecture - 32 bit or 64 bit
if [ $(getconf LONG_BIT | grep 64) ]; then ARCH="x86_64";  else ARCH="i386"; fi

# Install Features
apt-get -qq -y install build-essential libcairo2-dev ${JPEGTURBO} libpng12-dev libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev mysql-server mysql-client mysql-common mysql-utilities ${TOMCAT} freerdp ghostscript jq wget curl

# If Apt-Get fails to run completely the rest of this isn't going to work...
if [ $? != 0 ]; then
    echo "apt-get failed to install all required dependencies"
    exit
fi

SERVER=$(curl -s 'https://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.preferred|rtrimstr("/")')

# Add GUACAMOLE_HOME to $TOMCAT ENV
echo "" >> /etc/default/${TOMCAT}
echo "# GUACAMOLE EVN VARIABLE" >> /etc/default/${TOMCAT}
echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/${TOMCAT}

# Download Guacample Files
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/source/guacamole-server-${VERSION}-incubating.tar.gz
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-${VERSION}-incubating.war
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz

# Extract Guacamole Files
tar -xzf guacamole-server-${VERSION}-incubating.tar.gz
tar -xzf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xzf mysql-connector-java-${MCJVERSION}.tar.gz

# MAKE DIRECTORIES
mkdir /etc/guacamole
mkdir /etc/guacamole/lib
mkdir /etc/guacamole/extensions

# Install GUACD
cd guacamole-server-${VERSION}-incubating
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
systemctl enable guacd
cd ..

# Move files to correct locations
mv guacamole-${VERSION}-incubating.war /etc/guacamole/guacamole.war
ln -s /etc/guacamole/guacamole.war /var/lib/${TOMCAT}/webapps/
ln -s /usr/local/lib/freerdp/* /usr/lib/$ARCH-linux-gnu/freerdp/.
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

# SQL Code
SQLCODE="
create database guacamole_db;
create user 'guacamole_user'@'localhost' identified by \"$guacdbuserpassword\";
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
flush privileges;"

# Execute SQL Code
echo $SQLCODE | mysql -u root -p$mysqlrootpassword

# Add Guacamole Schema to newly created database
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword guacamole_db

# Cleanup
rm -rf guacamole-*
rm -rf mysql-connector-java-${MCJVERSION}*
