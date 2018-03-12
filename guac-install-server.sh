#!/bin/bash

# Version number of Guacamole to install
GUACVERSION="0.9.14"

# Ubuntu and Debian have different names of the libjpeg-turbo library for some reason...
source /etc/os-release
if [[ "${NAME}" == "Ubuntu" ]]
then
    JPEGTURBO="libjpeg-turbo8-dev"
    if [[ "${VERSION_ID}" == "16.04" ]]
    then
        LIBPNG="libpng12-dev"
    else
        LIBPNG="libpng-dev"
    fi
elif [[ "${NAME}" == *"Debian"* ]]
then
    JPEGTURBO="libjpeg62-turbo-dev"
    if [[ "${PRETTY_NAME}" == *"stretch"* ]]
    then
        LIBPNG="libpng-dev"
    else
        LIBPNG="libpng12-dev"
    fi
else
    echo "Unsupported Distro - Ubuntu or Debian Only"
    exit
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
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACVERSION}"

# Download Guacamole Server
wget -O guacamole-server-${GUACVERSION}.tar.gz ${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo "Failed to download guacamole-server-${GUACVERSION}.tar.gz"
    echo "${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz"
    exit
fi

# Extract Guacamole Files
tar -xzf guacamole-server-${GUACVERSION}.tar.gz

# Make Directories
mkdir /etc/guacamole

# Install guacd
cd guacamole-server-${GUACVERSION}

# Hack for gcc7
if [[ $(gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}' | grep "^7" | wc -l) -gt 0 ]]
then
    apt-get -y install gcc-6
    if [ $? -ne 0 ]
    then
        echo "apt-get failed to install gcc-6"
        exit
    fi
    CC="gcc-6" ./configure --with-init-dir=/etc/init.d
    CC="gcc-6" make
    CC="gcc-6" make install
else
    ./configure --with-init-dir=/etc/init.d
    make
    make install
fi

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
