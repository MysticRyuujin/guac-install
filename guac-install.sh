#!/bin/bash

# Guacamole Install Script (Fully Patched with Interactive Prompts, FreeRDP 3.x, Webcam, Kerberos, FUSE3, libusb, CUPS, and JSON support)
# Updated by Madelyn Tech

set -e

# Color codes for prompts
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Versions
guac_version="1.6.0"
freerdp_branch="3.2.0" # Stable FreeRDP release tag recommended
mysql_connector_version="8.0.33"

# Interactive prompts
clear
echo -e "${YELLOW}Welcome to the Madelyn Tech Guacamole installer with FreeRDP 3.x support.${NC}"
echo ""
echo -e "${GREEN}This script will install all components, including Webcam Redirection and Duo TOTP integration.${NC}"
echo ""
read -p "Do you want to install Duo TOTP for Guacamole? (y/n): " install_duo
read -p "Do you want to install MySQL and set up the Guacamole database? (y/n): " install_mysql

# Install all required dependencies
apt-get update
apt-get install -y build-essential libcairo2-dev libjpeg-turbo8-dev libpng-dev \
libtool-bin libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev \
libswscale-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev \
libpulse-dev libssl-dev libvorbis-dev libwebp-dev tomcat9 mysql-server \
mysql-client wget nano cmake git libx11-dev libxkbfile-dev \
libxext-dev libxinerama-dev libxcursor-dev libxv-dev libxi-dev libxrandr-dev \
libasound2-dev libavcodec-dev libavutil-dev libswscale-dev \
libkrb5-dev libjson-c-dev liburiparser-dev libsystemd-dev libcups2-dev \
libfuse3-dev libusb-1.0-0-dev

# Purge old FreeRDP 2.x packages if present
apt remove --purge -y freerdp2-dev libfreerdp2-* || true
apt autoremove -y
ldconfig

# Build and install FreeRDP 3.x stable release
if [ ! -d "$HOME/FreeRDP" ]; then
  git clone https://github.com/FreeRDP/FreeRDP.git "$HOME/FreeRDP"
fi
cd "$HOME/FreeRDP"
git fetch --tags
git checkout $freerdp_branch
git clean -xdf
mkdir -p build && cd build
cmake -DWITH_X11=ON -DWITH_PULSE=ON -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j"$(nproc)"
make install
ldconfig

# Download Guacamole Server
cd "$HOME"
wget "https://archive.apache.org/dist/guacamole/$guac_version/source/guacamole-server-$guac_version.tar.gz"
tar -xzf "guacamole-server-$guac_version.tar.gz"
cd "guacamole-server-$guac_version"

# Build and install Guacamole Server
./configure --with-init-dir=/etc/init.d
make -j"$(nproc)"
make install
ldconfig

# Setup Guacamole directories and MySQL extensions
mkdir -p /etc/guacamole /usr/share/tomcat9/.guacamole/extensions /usr/share/tomcat9/.guacamole/lib

# Download Guacamole Client
cd "$HOME"
wget "https://archive.apache.org/dist/guacamole/$guac_version/binary/guacamole-$guac_version.war" -O /var/lib/tomcat9/webapps/guacamole.war

# Setup MySQL Authentication Extension
cd "$HOME"
wget "https://archive.apache.org/dist/guacamole/$guac_version/binary/guacamole-auth-jdbc-$guac_version.tar.gz"
tar -xzf "guacamole-auth-jdbc-$guac_version.tar.gz"
cp "guacamole-auth-jdbc-$guac_version/mysql/guacamole-auth-jdbc-mysql-$guac_version.jar" \
  /usr/share/tomcat9/.guacamole/extensions/

# Download MySQL Connector manually
cd "$HOME"
wget "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-$mysql_connector_version.tar.gz"
tar -xzf "mysql-connector-java-$mysql_connector_version.tar.gz"
cp "mysql-connector-java-$mysql_connector_version/mysql-connector-java-$mysql_connector_version.jar" /usr/share/tomcat9/.guacamole/lib/mysql-connector-java.jar

# Install Duo TOTP if requested
if [[ "$install_duo" == "y" || "$install_duo" == "Y" ]]; then
  echo -e "${YELLOW}Installing Duo TOTP extension...${NC}"
  cd "$HOME"
  wget "https://archive.apache.org/dist/guacamole/$guac_version/binary/guacamole-auth-totp-$guac_version.tar.gz"
  tar -xzf "guacamole-auth-totp-$guac_version.tar.gz"
  cp "guacamole-auth-totp-$guac_version/guacamole-auth-totp-$guac_version.jar" \
    /usr/share/tomcat9/.guacamole/extensions/
fi

# Setup MySQL Database if requested
if [[ "$install_mysql" == "y" || "$install_mysql" == "Y" ]]; then
  echo -e "${YELLOW}Setting up MySQL Guacamole database...${NC}"
  mysql -u root -p <<EOF
CREATE DATABASE IF NOT EXISTS guacamole_db;
CREATE USER IF NOT EXISTS 'guacamole_user'@'localhost' IDENTIFIED BY 'yourpassword';
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
FLUSH PRIVILEGES;
EOF
fi

# Setup guacamole.properties
cat > /etc/guacamole/guacamole.properties <<EOF
guacd-hostname: localhost
guacd-port: 4822
mysql-hostname: localhost
mysql-port: 3306
mysql-database: guacamole_db
mysql-username: guacamole_user
mysql-password: yourpassword
EOF

# Permissions
chown -R tomcat9:tomcat9 /etc/guacamole /usr/share/tomcat9/.guacamole

# Prompt for MySQL root password to modify connection parameters
echo ""
echo -e "${GREEN}Webcam redirection setup:${NC}"
read -sp "Enter MySQL root password for webcam configuration: " mysql_root_password
echo ""

# Enable Webcam Redirection for default connection
mysql -u root -p"${mysql_root_password}" <<EOF
USE guacamole_db;
SET @conn_id = (SELECT connection_id FROM guacamole_connection WHERE connection_name = 'Windows Server' LIMIT 1);
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT @conn_id, 'enable-webcam', 'true'
WHERE @conn_id IS NOT NULL;
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT @conn_id, 'webcam-name', 'Integrated Webcam'
WHERE @conn_id IS NOT NULL;
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT @conn_id, 'webcam-fps', '15'
WHERE @conn_id IS NOT NULL;
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT @conn_id, 'webcam-width', '640'
WHERE @conn_id IS NOT NULL;
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT @conn_id, 'webcam-height', '480'
WHERE @conn_id IS NOT NULL;
EOF

# Restart services
systemctl restart guacd
tomcat9

# Done
echo ""
echo -e "${GREEN}Installation Complete${NC}"
echo "- Visit: http://localhost:8080/guacamole/"
echo "- Default login (username/password): guacadmin/guacadmin"
echo -e "${YELLOW}*** Be sure to change the password ***${NC}"

exit 0
