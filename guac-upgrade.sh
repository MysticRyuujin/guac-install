#!/bin/bash

# Version Numbers of Guacamole and MySQL Connector/J to download
VERSION="0.9.14"
MCJVERSION="5.1.45"

# I'm assuming tomcat7, you can change it here...
TOMCAT="tomcat7"

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${VERSION}-incubating"

# Stop tomcat
service ${TOMCAT} stop

# Download Guacamole server
wget -O guacamole-server-${VERSION}-incubating.tar.gz ${SERVER}/source/guacamole-server-${VERSION}-incubating.tar.gz
if [ ! -f ./guacamole-server-${VERSION}-incubating.tar.gz ]; then
    echo "Failed to download guacamole-server-${VERSION}-incubating.tar.gz"
    echo "${SERVER}/source/guacamole-server-${VERSION}-incubating.tar.gz"
    exit
fi

# Download Guacamole client
wget -O guacamole-${VERSION}-incubating.war ${SERVER}/binary/guacamole-${VERSION}-incubating.war
if [ ! -f ./guacamole-${VERSION}-incubating.war ]; then
    echo "Failed to download guacamole-${VERSION}-incubating.war"
    echo "${SERVER}/binary/guacamole-${VERSION}-incubating.war"
    exit
fi

# Download SQL components
wget -O guacamole-auth-jdbc-${VERSION}-incubating.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
if [ ! -f ./guacamole-auth-jdbc-${VERSION}-incubating.tar.gz ]; then
    echo "Failed to download guacamole-auth-jdbc-${VERSION}-incubating.tar.gz"
    echo "${SERVER}/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz"
    exit
fi

# Download the MySQL Connector/J
wget -O mysql-connector-java-${MCJVERSION}.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz
if [ ! -f ./mysql-connector-java-${MCJVERSION}.tar.gz ]; then
    echo "Failed to download guacamole-server-${VERSION}-incubating.tar.gz"
    echo "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz"
    exit
fi

# Upgrade Guacamole Server
tar -xzf guacamole-server-${VERSION}-incubating.tar.gz
cd guacamole-server-${VERSION}-incubating
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
systemctl enable guacd
cd ..

# Upgrade Guacamole Client
mv guacamole-${VERSION}-incubating.war /etc/guacamole/guacamole.war

# Upgrade SQL Components
tar -xzf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
cp guacamole-auth-jdbc-${VERSION}-incubating/mysql/guacamole-auth-jdbc-mysql-${VERSION}-incubating.jar /etc/guacamole/extensions/
tar -xzf mysql-connector-java-${MCJVERSION}.tar.gz
cp mysql-connector-java-${MCJVERSION}/mysql-connector-java-${MCJVERSION}-bin.jar /etc/guacamole/lib/
rm -rf mysql-connector-java-${MCJVERSION}*

# Check if there is an schema upgrade file, if there is run it (will prompt for password)
if [ -f "guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-${VERSION}.sql" ]
then
    mysql -u root -p guacamole_db < guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/upgrade/upgrade-pre-${VERSION}.sql
fi

# Start tomcat
service ${TOMCAT} start

# Cleanup
rm -rf guacamole*
