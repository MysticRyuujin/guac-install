#!/bin/bash

# Try to get database from /etc/guacamole/guacamole.properties
DATABASE=$(grep -oP 'mysql-database:\K.*' /etc/guacamole/guacamole.properties | awk '{print $1}')

# Get MySQL root password
echo
while true
do
    read -s -p "Enter MySQL ROOT Password: " mysqlrootpassword
    export MYSQL_PWD=${mysqlrootpassword}
    echo
    mysql -u root ${DATABASE} -e"quit" && break
    echo
done
echo

# Version Numbers of Guacamole and MySQL Connector/J to download
VERSION="0.9.14"
MCJVERSION="5.1.45"

# Get Tomcat Version
TOMCAT=$(ls /etc/ | grep tomcat)

# Get Current Guacamole Version
OLDVERSION=$(grep -oP 'Guacamole.API_VERSION = "\K[0-9\.]+' /var/lib/${TOMCAT}/webapps/guacamole/guacamole-common-js/modules/Version.js)

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${VERSION}"

# Stop tomcat
service ${TOMCAT} stop

# Download Guacamole server
wget -O guacamole-server-${VERSION}.tar.gz ${SERVER}/source/guacamole-server-${VERSION}.tar.gz
if [ ! -f ./guacamole-server-${VERSION}.tar.gz ]; then
    echo "Failed to download guacamole-server-${VERSION}.tar.gz"
    echo "${SERVER}/source/guacamole-server-${VERSION}.tar.gz"
    exit
fi

# Download Guacamole client
wget -O guacamole-${VERSION}.war ${SERVER}/binary/guacamole-${VERSION}.war
if [ ! -f ./guacamole-${VERSION}.war ]; then
    echo "Failed to download guacamole-${VERSION}.war"
    echo "${SERVER}/binary/guacamole-${VERSION}.war"
    exit
fi

# Download SQL components
wget -O guacamole-auth-jdbc-${VERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${VERSION}.tar.gz
if [ ! -f ./guacamole-auth-jdbc-${VERSION}.tar.gz ]; then
    echo "Failed to download guacamole-auth-jdbc-${VERSION}.tar.gz"
    echo "${SERVER}/binary/guacamole-auth-jdbc-${VERSION}.tar.gz"
    exit
fi

# Download the MySQL Connector/J
wget -O mysql-connector-java-${MCJVERSION}.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz
if [ ! -f ./mysql-connector-java-${MCJVERSION}.tar.gz ]; then
    echo "Failed to download mysql-connector-java-${MCJVERSION}.tar.gz"
    echo "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz"
    exit
fi

# Upgrade Guacamole Server
tar -xzf guacamole-server-${VERSION}.tar.gz
cd guacamole-server-${VERSION}
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
systemctl enable guacd
cd ..

# Upgrade Guacamole Client
mv guacamole-${VERSION}.war /etc/guacamole/guacamole.war

# Upgrade SQL Components
tar -xzf guacamole-auth-jdbc-${VERSION}.tar.gz
cp guacamole-auth-jdbc-${VERSION}/mysql/guacamole-auth-jdbc-mysql-${VERSION}.jar /etc/guacamole/extensions/
tar -xzf mysql-connector-java-${MCJVERSION}.tar.gz
cp mysql-connector-java-${MCJVERSION}/mysql-connector-java-${MCJVERSION}-bin.jar /etc/guacamole/lib/
rm -rf mysql-connector-java-${MCJVERSION}*

# Get list of SQL Upgrade Files
UPGRADEFILES=($(ls -1 guacamole-auth-jdbc-${VERSION}/mysql/schema/upgrade/ | sort -V))

# Compare SQL Upgrage Files against old version, apply upgrades as needed
for FILE in ${UPGRADEFILES[@]}
do
    FILEVERSION=$(echo ${FILE} | grep -oP 'upgrade-pre-\K[0-9\.]+(?=\.)')
    if [[ $(echo -e "${FILEVERSION}\n${OLDVERSION}" | sort -V | head -n1) == ${OLDVERSION} && ${FILEVERSION} != ${OLDVERSION} ]]
    then
        mysql -u root ${DATABASE} < guacamole-auth-jdbc-${VERSION}/mysql/schema/upgrade/${FILE}
    fi
done

# Start tomcat
service ${TOMCAT} start

# Cleanup
rm -rf guacamole*
unset MYSQL_PWD
