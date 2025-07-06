""﻿#!/bin/bash
# Something isn't working? # tail -f /var/log/messages /var/log/syslog /var/log/tomcat*/*.out /var/log/mysql/*.log

# Check if user is root or sudo
if ! [ $( id -u ) = 0 ]; then
    echo "Please run this script as sudo or root" 1>&2
    exit 1
fi

# Check to see if any old files left over
if [ "$( find . -maxdepth 1 \( -name 'guacamole-*' -o -name 'mysql-connector-java-*' \) )" != "" ]; then
    echo "Possible temp files detected. Please review 'guacamole-*' & 'mysql-connector-java-*'" 1>&2
    exit 1
fi

# BEGIN MODIFIED SECTION: Inject FreeRDP 3.x webcam logic, dependencies, and prompts

# Versions
GUACVERSION="1.6.0"
FREERDP_BRANCH="3.2.0"
MCJVER="8.0.33"

# Colors to use for output
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Prompt for TOTP and Duo
installTOTP=""
installDuo=""
echo -e -n "${CYAN}MFA: Would you like to install TOTP (choose 'N' if you want Duo)? (y/N): ${NC}"
read PROMPT
if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
    installTOTP=true
    installDuo=false
else
    echo -e -n "${CYAN}MFA: Would you like to install Duo (configure after install)? (y/N): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
        installDuo=true
    fi
fi

# Install dependencies (including what's needed for FreeRDP 3.x, webcam, and missing pieces)
echo -e "${BLUE}Installing dependencies...${NC}"
apt-get update
apt-get install -y build-essential libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev \
libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libpango1.0-dev libssh2-1-dev libtelnet-dev \
libvncserver-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev tomcat9 mysql-server mysql-client \
libkrb5-dev libjson-c-dev liburiparser-dev libsystemd-dev libcups2-dev libfuse3-dev libusb-1.0-0-dev \
librhash0 cmake git libx11-dev libxkbfile-dev libxext-dev libxinerama-dev libxcursor-dev libxv-dev \
libxi-dev libxrandr-dev libasound2-dev libwebkit2gtk-4.0-dev xsltproc pkg-config \
libpkcs11-helper1 libgtk-3-dev

# Remove conflicting FreeRDP 2.x packages
apt remove --purge -y freerdp2-dev libfreerdp2-* || true
apt autoremove -y
ldconfig

# Build FreeRDP 3.x
cd /usr/src || exit 1
git clone https://github.com/FreeRDP/FreeRDP.git || true
cd FreeRDP || exit 1
git fetch --tags
git checkout ${FREERDP_BRANCH}
git clean -xdf
mkdir -p build && cd build
cmake -DWITH_X11=ON -DWITH_PULSE=ON -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j"$(nproc)"
make install
ldconfig

# Download and extract Guacamole
cd /usr/src || exit 1
wget https://archive.apache.org/dist/guacamole/${GUACVERSION}/source/guacamole-server-${GUACVERSION}.tar.gz
wget https://archive.apache.org/dist/guacamole/${GUACVERSION}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz
wget https://archive.apache.org/dist/guacamole/${GUACVERSION}/binary/guacamole-${GUACVERSION}.war -O /var/lib/tomcat9/webapps/guacamole.war
wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVER}.tar.gz

tar -xzf guacamole-server-${GUACVERSION}.tar.gz
cd guacamole-server-${GUACVERSION}
./configure --with-init-dir=/etc/init.d --enable-allow-freerdp-snapshots
make -j"$(nproc)"
make install
ldconfig

# Setup directories
tar -xzf ../guacamole-auth-jdbc-${GUACVERSION}.tar.gz
tar -xzf ../mysql-connector-java-${MCJVER}.tar.gz
mkdir -p /etc/guacamole/lib /etc/guacamole/extensions
cp mysql-connector-java-${MCJVER}/mysql-connector-java-${MCJVER}.jar /etc/guacamole/lib/
cp guacamole-auth-jdbc-${GUACVERSION}/mysql/guacamole-auth-jdbc-mysql-${GUACVERSION}.jar /etc/guacamole/extensions/

# Prompt for MySQL root password
echo -e -n "${CYAN}Enter MySQL root password for webcam configuration: ${NC}"
read -s mysqlRootPwd

# Insert webcam parameters
echo "Configuring webcam redirection in database..."
mysql -u root -p"${mysqlRootPwd}" <<EOF
USE guacamole_db;
SET @conn_id = (SELECT connection_id FROM guacamole_connection WHERE connection_name = 'Windows Server' LIMIT 1);
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT @conn_id, 'enable-webcam', 'true' WHERE @conn_id IS NOT NULL;
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT @conn_id, 'webcam-name', 'Integrated Webcam' WHERE @conn_id IS NOT NULL;
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT @conn_id, 'webcam-fps', '15' WHERE @conn_id IS NOT NULL;
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT @conn_id, 'webcam-width', '640' WHERE @conn_id IS NOT NULL;
INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value) SELECT @conn_id, 'webcam-height', '480' WHERE @conn_id IS NOT NULL;
EOF

# Restart services
systemctl restart guacd
tomcat9

# Final output
echo -e "${GREEN}Installation Complete${NC}"
echo -e "- Visit: http://localhost:8080/guacamole/"
echo -e "- Default login (username/password): guacadmin/guacadmin"
echo -e "${YELLOW}*** Be sure to change the password ***${NC}"

exit 0
