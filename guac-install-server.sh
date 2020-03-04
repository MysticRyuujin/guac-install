#!/bin/bash

# Check if user is root or sudo
if ! [ $(id -u) = 0 ]; then echo "Please run this script as sudo or root"; exit 1 ; fi

# Version number of Guacamole to install
GUACVERSION="1.1.0"

# Different version of Ubuntu and Debian have different package names...
source /etc/os-release
if [[ "${NAME}" == "Ubuntu" ]]; then
    # Ubuntu > 18.04 does not include universe repo by default
    # Add the "Universe" repo, don't update
    add-apt-repository -yn universe
    # Set package names depending on version
    JPEGTURBO="libjpeg-turbo8-dev"
    if [[ "${VERSION_ID}" == "16.04" ]]
    then
        LIBPNG="libpng12-dev"
    else
        LIBPNG="libpng-dev"
    fi
elif [[ "${NAME}" == *"Debian"* ]] || [[ "${NAME}" == *"Raspbian GNU/Linux"* ]] || [[ "${NAME}" == *"Kali GNU/Linux"* ]]; then
    JPEGTURBO="libjpeg62-turbo-dev"
    if [[ "${PRETTY_NAME}" == *"stretch"* ]] || [[ "${PRETTY_NAME}" == *"buster"* ]] || [[ "${PRETTY_NAME}" == *"Kali GNU/Linux Rolling"* ]]; then
        LIBPNG="libpng-dev"
    else
        LIBPNG="libpng12-dev"
    fi
else
    echo "Unsupported Distro - Ubuntu, Debian, Kali or Raspbian Only"
    exit 1
fi

# Install Server Features
apt-get -qq update
export DEBIAN_FRONTEND=noninteractive
apt-get -y install build-essential libcairo2-dev ${JPEGTURBO} ${LIBPNG} libossp-uuid-dev libavcodec-dev libavutil-dev \
libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev libwebsockets-dev wget libtool-bin

# If apt fails to run completely the rest of this isn't going to work...
if [ $? != 0 ]; then
    echo "apt-get failed to install all required dependencies."
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
else
    # Extract Guacamole Files
    tar -xzf guacamole-server-${GUACVERSION}.tar.gz
fi

# Make Directories
mkdir -p /etc/guacamole

# Install guacd (Guacamole-server)
cd guacamole-server-${GUACVERSION}
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
systemctl start guacd
systemctl enable guacd

# Cleanup
rm -rf guacamole-*
