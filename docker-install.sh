#!/bin/bash
# WORKING ON UBUNTU 16.04 LTS

VERSION="0.9.13"

read -s -p "Enter the password that will be used for MySQL Root: " MYSQLROOTPASSWORD
echo
read -s -p "Enter the password that will be used for the Guacamole database: " GUACDBUSERPASSWORD
echo

#Install Stuff
apt-get update
apt-get -qq -y install docker.io mysql-client wget jq curl

# Get perfered download server
SERVER=$(curl -s 'https://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.preferred|rtrimstr("/")')

# Download the guacamole auth files for MySQL
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xzf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz

# Start MySQL
docker run --restart=always --detach --name=mysql --env="MYSQL_ROOT_PASSWORD=$MYSQLROOTPASSWORD" --publish 3306:3306 mysql

# Create the Guacamole database and the user account

# SQL Code
SQLCODE="
create database guacamole_db;
create user 'guacamole_user'@'%' identified by '$guacdbuserpassword';
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'%';
flush privileges;"

# Execute SQL Code
echo $SQLCODE | mysql -h 127.0.0.1 -P 3306 -u root -p$MYSQLROOTPASSWORD

cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/*.sql | mysql -u root -p$MYSQLROOTPASSWORD -h 127.0.0.1 -P 3306 guacamole_db

docker run --restart=always --name guacd -d guacamole/guacd
docker run --restart=always --name guacamole  --link mysql:mysql --link guacd:guacd -e MYSQL_HOSTNAME=127.0.0.1 -e MYSQL_DATABASE=guacamole_db -e MYSQL_USER=guacamole_user -e MYSQL_PASSWORD=$GUACDBUSERPASSWORD --detach -p 8080:8080 guacamole/guacamole

rm -rf guacamole-auth-jdbc-${VERSION}-incubating*
