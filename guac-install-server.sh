#!/bin/bash

VERSION="0.9.12"

# Install Server Features
apt-get update
apt-get -y install build-essential libcairo2-dev libjpeg-turbo8-dev libpng12-dev libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev jq curl wget

# If Apt-Get fails to run completely the rest of this isn't going to work...
if [ $? != 0 ]
then
    echo "apt-get failed to install all required dependencies. Are you on Ubuntu 16.04 LTS?"
    exit
fi

SERVER=$(curl -s 'https://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.preferred|rtrimstr("/")')

# Download Guacample Files
wget ${SERVER}/incubator/guacamole/${VERSION}-incubating/source/guacamole-server-${VERSION}-incubating.tar.gz

# Extract Guacamole Files
tar -xzf guacamole-server-${VERSION}-incubating.tar.gz

# MAKE DIRECTORIES
mkdir /etc/guacamole

# Install GUACD
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
