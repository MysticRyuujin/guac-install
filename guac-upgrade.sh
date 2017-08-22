#!/bin/bash

# Version Numbers of Guacamole and MySQL Connector/J to download
VERSION="0.9.13"
MCJVERSION="5.1.43"

# I'm assuming tomcat8, you can change it here...
TOMCAT="tomcat8"

SERVER=$(curl -s 'https://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.preferred|rtrimstr("/")')

# Stop tomcat
service ${TOMCAT} stop

# Download and install Guacamole server
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/source/guacamole-server-${VERSION}-incubating.tar.gz
tar -xzf guacamole-server-${VERSION}-incubating.tar.gz
cd guacamole-server-${VERSION}-incubating
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
systemctl enable guacd
cd ..

# Download and replace Guacamole client
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-${VERSION}-incubating.war
mv guacamole-${VERSION}-incubating.war /etc/guacamole/guacamole.war

# Download and upgrade SQL components
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xzf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
cp guacamole-auth-jdbc-${VERSION}-incubating/mysql/guacamole-auth-jdbc-mysql-${VERSION}-incubating.jar /etc/guacamole/extensions/

# Upgrade the MySQL Connector/J
wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz
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
