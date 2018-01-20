#!/bin/bash

VERSION="0.9.14"

# Ubuntu and Debian have different names of the libjpeg-turbo library for some reason...
source /etc/lsb-release

if [ $DISTRIB_ID == "Ubuntu" ]
then
    JPEGTURBO="libjpeg-turbo8-dev"
else
    JPEGTURBO="libjpeg62-turbo-dev"
fi

# Ubuntu 16.10 has a different name for libpng12-dev for some reason...
if [ $DISTRIB_RELEASE == "16.10" ]
then
    LIBPNG="libpng-dev"
else
    LIBPNG="libpng12-dev"
fi

# Install Server Features
apt update
apt -y install build-essential libcairo2-dev ${JPEGTURBO} ${LIBPNG} libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev libfreerdp-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev jq curl wget

# If apt fails to run completely the rest of this isn't going to work...
if [ $? != 0 ]
then
    echo "apt failed to install all required dependencies."
    exit
fi

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${VERSION}-incubating"

# Download Guacamole Files
wget -O guacamole-server-${VERSION}-incubating.tar.gz ${SERVER}/source/guacamole-server-${VERSION}-incubating.tar.gz
if [ ! -f ./guacamole-server-${VERSION}-incubating.tar.gz ]; then
    echo "Failed to download guacamole-server-${VERSION}-incubating.tar.gz"
    echo "${SERVER}/source/guacamole-server-${VERSION}-incubating.tar.gz"
    exit
fi

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
