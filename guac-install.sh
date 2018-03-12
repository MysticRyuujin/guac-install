#!/bin/bash

# Version number of Guacamole to install
GUACVERSION="0.9.14"

# Update apt so we can search apt-cache for newest tomcat version supported
apt-get update

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
source /etc/os-release
if [[ "${NAME}" == "Ubuntu" ]]
then
    JPEGTURBO="libjpeg-turbo8-dev"
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
    exit
fi

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
apt-get -y install build-essential libcairo2-dev ${JPEGTURBO} ${LIBPNG} libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev mysql-server mysql-client mysql-common mysql-utilities libmysql-java ${TOMCAT} freerdp-x11 \
ghostscript wget dpkg-dev

# If apt fails to run completely the rest of this isn't going to work...
if [ $? -ne 0 ]; then
    echo "apt-get failed to install all required dependencies"
    exit
fi

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACVERSION}"

# Download Guacamole Server
wget -O guacamole-server-${GUACVERSION}.tar.gz ${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-server-${GUACVERSION}.tar.gz"
    echo "${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz"
    exit
fi

# Download Guacamole Client
wget -O guacamole-${GUACVERSION}.war ${SERVER}/binary/guacamole-${GUACVERSION}.war
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-${GUACVERSION}.war"
    echo "${SERVER}/binary/guacamole-${GUACVERSION}.war"
    exit
fi

# Download Guacamole authentication extensions
wget -O guacamole-auth-jdbc-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    echo "${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    exit
fi

# Extract Guacamole files
tar -xzf guacamole-server-${GUACVERSION}.tar.gz
tar -xzf guacamole-auth-jdbc-${GUACVERSION}.tar.gz

# Make directories
mkdir -p /etc/guacamole/lib
mkdir -p /etc/guacamole/extensions

# Install guacd
cd guacamole-server-${GUACVERSION}

# Hack for gcc7
if [[ $(gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}' | grep "^7" | wc -l) -gt 0 ]]
then
    apt-get -y install gcc-6
    if [ $? -ne 0 ]
    then
        echo "apt-get failed to install gcc-6"
        exit
    fi
    CC="gcc-6" ./configure --with-init-dir=/etc/init.d
    CC="gcc-6" make
    CC="gcc-6" make install
else
    ./configure --with-init-dir=/etc/init.d
    make
    make install
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
echo "mysql-database: guacamole_db" >> /etc/guacamole/guacamole.properties
echo "mysql-username: guacamole_user" >> /etc/guacamole/guacamole.properties
echo "mysql-password: $guacdbuserpassword" >> /etc/guacamole/guacamole.properties

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
cat guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword guacamole_db

# Ensure guacd is started
service guacd start

# Cleanup
rm -rf guacamole-*

echo -e "Installation Complete\nhttp://localhost:8080/guacamole/\nDefault login guacadmin:guacadmin\nBe sure to change the password."
