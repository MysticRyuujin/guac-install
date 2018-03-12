#!/bin/bash

# Version Numbers of Guacamole to download
GUACVERSION="0.9.14"

# Try to get database from /etc/guacamole/guacamole.properties
DATABASE=$(grep -oP 'mysql-database:\K.*' /etc/guacamole/guacamole.properties | awk '{print $1}')
MYSQL_SERVER=$(grep -oP 'mysql-hostname:\K.*' /etc/guacamole/guacamole.properties | awk '{print $1}')

# Get script arguments for non-interactive mode
while [ "$1" != "" ]; do
    case $1 in
        -m | --mysqlpwd )
            shift
            mysqlpwd="$1"
            ;;
    esac
    shift
done

# Get MySQL root password
if [ -n "$mysqlpwd" ]; then
        mysqlrootpassword=$mysqlpwd
        export MYSQL_PWD=${mysqlrootpassword}
        mysql -u root -h ${MYSQL_SERVER} ${DATABASE} -e"quit" || exit
else
    echo
    while true
    do
        read -s -p "Enter MySQL ROOT Password: " mysqlrootpassword
        export MYSQL_PWD=${mysqlrootpassword}
        echo
        mysql -u root -h ${MYSQL_SERVER} ${DATABASE} -e"quit" && break
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

# Stop tomcat
service ${TOMCAT} stop

# Download Guacamole server
wget -O guacamole-server-${GUACVERSION}.tar.gz ${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-server-${GUACVERSION}.tar.gz"
    echo "${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz"
    exit
fi

# Download Guacamole client
wget -O guacamole-${GUACVERSION}.war ${SERVER}/binary/guacamole-${GUACVERSION}.war
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-${GUACVERSION}.war"
    echo "${SERVER}/binary/guacamole-${GUACVERSION}.war"
    exit
fi

# Download SQL components
wget -O guacamole-auth-jdbc-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    echo "${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    exit
fi

# Hack for gcc7
if [[ $(gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}' | grep "^7" | wc -l) -gt 0 ]]
then
    apt-get -y install gcc-6
fi

# Upgrade Guacamole Server
tar -xzf guacamole-server-${GUACVERSION}.tar.gz
cd guacamole-server-${GUACVERSION}
CC="gcc-6" ./configure --with-init-dir=/etc/init.d
CC="gcc-6" make
CC="gcc-6" make install
ldconfig
systemctl enable guacd
cd ..

# Upgrade Guacamole Client
mv guacamole-${GUACVERSION}.war /etc/guacamole/guacamole.war

# Upgrade SQL Components
tar -xzf guacamole-auth-jdbc-${GUACVERSION}.tar.gz
cp guacamole-auth-jdbc-${GUACVERSION}/mysql/guacamole-auth-jdbc-mysql-${GUACVERSION}.jar /etc/guacamole/extensions/

# Get list of SQL Upgrade Files
UPGRADEFILES=($(ls -1 guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/upgrade/ | sort -V))

# Compare SQL Upgrage Files against old version, apply upgrades as needed
for FILE in ${UPGRADEFILES[@]}
do
    FILEVERSION=$(echo ${FILE} | grep -oP 'upgrade-pre-\K[0-9\.]+(?=\.)')
    if [[ $(echo -e "${FILEVERSION}\n${OLDVERSION}" | sort -V | head -n1) == ${OLDVERSION} && ${FILEVERSION} != ${OLDVERSION} ]]
    then
        echo "Patching ${DATABASE} with ${FILE}"
        mysql -u root -h ${MYSQL_SERVER} ${DATABASE} < guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/upgrade/${FILE}
    fi
done

# Start tomcat
service ${TOMCAT} start
service guacd start

# Cleanup
rm -rf guacamole*
unset MYSQL_PWD
