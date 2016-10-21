#!/bin/bash
# WORKING ON UBUNTU 16.04 LTS

read -s -p "Enter the password that will be used for MySQL Root: " MYSQLROOTPASSWORD
read -s -p "Enter the password that will be used for the Guacamole database: " GUACDBUSERPASSWORD

#Install Stuff
apt-get install docker.io mysql-client wget

# Download the guacamole auth files for MySQL
wget -O guacamole-auth-jdbc-0.9.9.tar.gz http://sourceforge.net/projects/guacamole/files/current/extensions/guacamole-auth-jdbc-0.9.9.tar.gz
tar -xzf guacamole-auth-jdbc-0.9.9.tar.gz

# Start MySQL
docker run --restart=always --detach --name=mysql --env="MYSQL_ROOT_PASSWORD=$MYSQLROOTPASSWORD" --publish 3306:3306 mysql

# Create the Guacamole database and the user account
echo "create database guacamole_db; create user 'guacamole_user'@'localhost' identified by \"$GUACDBUSERPASSWORD\";GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';flush privileges;" | mysql -h 127.0.0.1 -P 3306 -u root -p$MYSQLROOTPASSWORD

cat guacamole-auth-jdbc-0.9.9/mysql/schema/*.sql | mysql -u root -p$MYSQLROOTPASSWORD -h 127.0.0.1 -P 3306 guacamole_db

docker run --restart=always --name guacd -d glyptodon/guacd
docker run --restart=always --name guacamole  --link mysql:mysql --link guacd:guacd -e MYSQL_HOSTNAME=127.0.0.1 -e MYSQL_DATABASE=guacamole_db -e MYSQL_USER=guacamole_user -e MYSQL_PASSWORD=$GUACDBUSERPASSWORD --detach -p 8080:8080 glyptodon/guacamole
