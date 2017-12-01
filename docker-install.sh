#!/bin/bash
# WORKING ON UBUNTU 16.04 LTS

VERSION="0.9.13"

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

#Install Stuff
apt update
apt -y install docker.io mysql-client wget

# Get perfered download server
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${VERSION}-incubating"

# Download the Guacamole auth files for MySQL
wget -O guacamole-auth-jdbc-${VERSION}-incubating.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xzf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz

# Start MySQL
docker run --restart=always --detach --name=mysql --env="MYSQL_ROOT_PASSWORD=$mysqlrootpassword" --publish 3306:3306 mysql

# Sleep to let MySQL load (there's probably a better way to do this)
echo "Waiting 30 seconds for MySQL to load"
sleep 30

# Create the Guacamole database and the user account
# SQL Code
SQLCODE="
create database guacamole_db; 
create user 'guacamole_user'@'%' identified by '$guacdbuserpassword'; 
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'%'; 
flush privileges;"

# Execute SQL Code
echo $SQLCODE | mysql -h 127.0.0.1 -P 3306 -u root -p$mysqlrootpassword

cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword -h 127.0.0.1 -P 3306 guacamole_db

docker run --restart=always --name guacd -d guacamole/guacd
docker run --restart=always --name guacamole  --link mysql:mysql --link guacd:guacd -e MYSQL_HOSTNAME=127.0.0.1 -e MYSQL_DATABASE=guacamole_db -e MYSQL_USER=guacamole_user -e MYSQL_PASSWORD=$guacdbuserpassword --detach -p 8080:8080 guacamole/guacamole

rm -rf guacamole-auth-jdbc-${VERSION}-incubating*
