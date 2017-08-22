#!/bin/bash

VERSION="0.9.13"

# Ubuntu and Debian have different names of the libjpeg-turbo library for some reason...
if [ `egrep -c "ID=ubuntu" /etc/os-release` -gt 0 ]
then
    JPEGTURBO="libjpeg-turbo8-dev"
else
    JPEGTURBO="libjpeg62-turbo-dev"
fi

# Install Server Features
apt update
apt -y install build-essential libcairo2-dev $JPEGTURBO libpng12-dev libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev jq curl wget

# If apt fails to run completely the rest of this isn't going to work...
if [ $? != 0 ]
then
    echo "apt failed to install all required dependencies."
    exit
fi

SERVER=$(curl -s 'https://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.preferred|rtrimstr("/")')

# Download Guacamole Files
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/source/guacamole-server-${VERSION}-incubating.tar.gz

# Extract Guacamole Files
tar -xzf guacamole-server-${VERSION}-incubating.tar.gz

# Make Directories
mkdir /etc/guacamole

# Install guacd
cd guacamole-server-${VERSION}-incubating
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
cd ..

# Configure guacamole.properties
echo "[server]" >> /etc/guacamole/guacd.conf
echo "bind_host = 0.0.0.0" >> /etc/guacamole/guacd.conf
echo "bind_port = 4822" >> /etc/guacamole/guacd.conf

# Configure startup
systemctl enable guacd
systemctl start guacd

# Cleanup
rm -rf guacamole-*
