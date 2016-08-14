#!/bin/bash

# Grab a password for MySQL Root
read -s -p "Enter the password that will be used for MySQL Root: " mysqlrootpassword
debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlrootpassword"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysqlrootpassword"

# Grab a password for Guacamole Database User Account
read -s -p "Enter the password that will be used for the Guacamole database: " guacdbuserpassword

# Install Features
apt-get -y install libcairo2-dev libpng12-dev libossp-uuid-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev mysql-server mysql-client mysql-common mysql-utilities tomcat8 freerdp ghostscript wget curl
wget -O libjpeg-turbo-official_1.5.0_amd64.deb http://downloads.sourceforge.net/project/libjpeg-turbo/1.5.0/libjpeg-turbo-official_1.5.0_amd64.deb
dpkg -i libjpeg-turbo-official_1.5.0_amd64.deb

# Add GUACAMOLE_HOME to Tomcat8 ENV
echo "" >> /etc/default/tomcat8
echo "# GUACAMOLE EVN VARIABLE" >> /etc/default/tomcat8
echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat8

# Download Guacample Files
wget -O guacamole-0.9.9.war http://downloads.sourceforge.net/project/guacamole/current/binary/guacamole-0.9.9.war
wget -O guacamole-server-0.9.9.tar.gz http://sourceforge.net/projects/guacamole/files/current/source/guacamole-server-0.9.9.tar.gz
wget -O guacamole-auth-jdbc-0.9.9.tar.gz http://sourceforge.net/projects/guacamole/files/current/extensions/guacamole-auth-jdbc-0.9.9.tar.gz
wget -O mysql-connector-java-5.1.38.tar.gz http://dev.mysql.com/get/Downloads/Connector/j/mysql-connector-java-5.1.38.tar.gz

#Extract Guacamole Files
tar -xzf guacamole-server-0.9.9.tar.gz
tar -xzf guacamole-auth-jdbc-0.9.9.tar.gz
tar -xzf mysql-connector-java-5.1.38.tar.gz

# MAKE DIRECTORIES
mkdir /etc/guacamole
mkdir /etc/guacamole/lib
mkdir /etc/guacamole/extensions

# Install GUACD
cd guacamole-server-0.9.9
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
systemctl enable guacd
cd ..

# Move files to correct locations
mv guacamole-0.9.9.war /etc/guacamole/guacamole.war
ln -s /etc/guacamole/guacamole.war /var/lib/tomcat8/webapps/
ln -s /usr/local/lib/freerdp/* /usr/lib/x86_64-linux-gnu/freerdp/.
cp mysql-connector-java-5.1.38/mysql-connector-java-5.1.38-bin.jar /etc/guacamole/lib/
cp guacamole-auth-jdbc-0.9.9/mysql/guacamole-auth-jdbc-mysql-0.9.9.jar /etc/guacamole/extensions/

# Configure guacamole.properties
echo "mysql-hostname: localhost" >> /etc/guacamole/guacamole.properties
echo "mysql-port: 3306" >> /etc/guacamole/guacamole.properties
echo "mysql-database: guacamole_db" >> /etc/guacamole/guacamole.properties
echo "mysql-username: guacamole_user" >> /etc/guacamole/guacamole.properties
echo "mysql-password: $guacdbuserpassword" >> /etc/guacamole/guacamole.properties
rm -rf /usr/share/tomcat8/.guacamole
ln -s /etc/guacamole /usr/share/tomcat8/.guacamole

# restart tomcat
service tomcat8 restart

mysql -u root -p$mysqlrootpassword
create database guacamole_db;
create user 'guacamole_user'@'localhost' identified by "$guacdbuserpassword";
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
flush privileges;
quit

cat guacamole-auth-jdbc-0.9.9/mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword guacamole_db

rm libjpeg-turbo-official_1.5.0_amd64.deb
rm guacamole-server-0.9.9.tar.gz
rm guacamole-auth-jdbc-0.9.9.tar.gz
rm mysql-connector-java-5.1.38.tar.gz

rm -rf mysql-connector-java-5.1.38/
rm -rf guacamole-auth-jdbc-0.9.9/
rm -rf guacamole-server-0.9.9/