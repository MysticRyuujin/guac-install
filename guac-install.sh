#!/bin/bash

# Guacamole Install Script (Reworked for FreeRDP 3.x)
# Updated by Madelyn Tech to support webcam redirection (RDPECAM)

set -e

# Versions
guac_version="1.6.0"
freerdp_branch="master" # Adjust this to a stable 3.x tag if needed

# Install dependencies (excluding freerdp2-dev)
apt-get update
apt-get install -y build-essential libcairo2-dev libjpeg-turbo8-dev libpng-dev \
  libtool-bin libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev \
  libswscale-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev \
  libpulse-dev libssl-dev libvorbis-dev libwebp-dev tomcat9 mysql-server \
  mysql-client libmysql-java wget nano cmake git libx11-dev libxkbfile-dev \
  libxext-dev libxinerama-dev libxcursor-dev libxv-dev libxi-dev libxrandr-dev \
  libasound2-dev libavcodec-dev libavutil-dev libswscale-dev

# Purge any existing FreeRDP 2.x packages to avoid conflicts
apt remove --purge -y freerdp2-dev libfreerdp2-* || true
apt autoremove -y
ldconfig

# Build and install FreeRDP 3.x
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
ln -s /usr/share/java/mysql-connector-java.jar /usr/share/tomcat9/.guacamole/lib/mysql-connector-java.jar

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

# Restart services
systemctl restart guacd
tomcat9

# Done
echo ""
echo "Installation Complete"
echo "- Visit: http://localhost:8080/guacamole/"
echo "- Default login (username/password): guacadmin/guacadmin"
echo "*** Be sure to change the password ***."

exit 0
