# guac-install

I've maintained this script for quite a few years now with the help of the other contributors and it seems to be getting more and more fragmented as libraries and system OSes diverge in their package management. I plan to continue maintaining the install script, but, I do highly suggest that more people try to use the containerized (docker) version. As it should work on basically any 64bit OS with Docker support. (That means it doesn't work on 32bit ARM/Rasp Pi)

## NOTE: The fixes below are not to be used UNLESS you're having issues, don't run these for no reason, use the distro maintainers version unless there's a reason not to.

## NOTE: Ubuntu users having issues with RDP have reported the following fix:
```
sudo add-apt-repository ppa:remmina-ppa-team/remmina-next
sudo apt-get update
sudo apt-get install freerdp2-dev freerdp2-x11
```

## NOTE: Debian users having issues with RDP have reported the following fix:
```
sudo bash -c 'echo "deb http://deb.debian.org/debian buster-backports main" >> /etc/apt/sources.list.d/backports.list'
sudo apt update
sudo apt -y -t buster-backports install freerdp2-dev libpulse-dev
```

Script for installing Guacamole 1.3.0 on Ubuntu 16.04 or newer (with MySQL, or remote MySQL). It should also work on pure [Debian](https://www.debian.org/), [Raspbian](https://www.raspberrypi.org/downloads/raspbian/), [Linux Mint](https://linuxmint.com/) (18/LMDE 4 or newer) or [Kali Linux](https://www.kali.org/). I have tested this with Debian 10.3.0 (Buster). **If other versions don't work please open an issue.** It is likely due to a required library having a different name.

Run script, enter MySQL Root Password and Guacamole User password. Guacamole User is used to connect to the Guacamole Database. Be sure to save these!

The script attempts to install `tomcat9` by default (it will fall back on `tomcat8` **if the available version is 8.5.x or newer**, otherwise it will fall back to `tomcat7`). If you want to manually specify a tomcat version there's a commented out line you can modify. Have at it.

If you're looking to also have NGINX / Let's Encrypt / HTTPS click [HERE](https://github.com/bigredthelogger/guacamole)

## MFA/2FA

By default the script will not install MFA support (QR code for Google/Microsoft Authenticator, Duo Mobile, etc. or Duo Push), if you do want MFA support you can use the `-t` or `--totp` or for Duo `-d` or `--duo` flags on the command line. Or modify the script variables `installTOTP=true` or `installDuo=true`. **Do not install both**

## FYI

Here's a cool PowerShell module for using the Guacamole API: https://github.com/UpperM/guacamole-powershell

Does not work if you have MFA turned on (however, you can authenticate via the gui and get a token to use it that way)

## How to Run:

### Download file directly from here:

`wget https://git.io/fxZq5 -O guac-install.sh`

### Make it executable:

`chmod +x guac-install.sh`

### Run it as root:

Interactive (asks for passwords):

`./guac-install.sh`

Non-Interactive (values provided via cli):

`./guac-install.sh --mysqlpwd password --guacpwd password --nomfa --installmysql`

OR

`./guac-install.sh -r password -gp password -o -i`

Once installation is done you can access Guacamole by browsing to: http://<host_or_ip>:8080/guacamole/
The default credentials are `guacadmin` as both username and password. Please change them or disable guacadmin after install!

# guac-upgrade

Script for upgrading currently installed Guacamole instance (previously installed via this script/guide).  This will also now update the TOTP or Duo extensions if used.

If looks for the tomcat folder in /etc/ (E.G. `/etc/tomcat7` or `/etc/tomcat8`) hopefully that works to identify the correct tomcat version/path :smile: I'm open to suggestions/pull requests for a cleaner method.

## All Switches

Install MySQL:

`-i or --installmysql`

Do *NOT* install MySQL:

`-n or --nomysql`

MySQL Host:

`-h or --mysqlhost`

MySQL Port:

`-p or --mysqlport`

MySQL Root Password:

`-r or --mysqlpwd`

Guacamole Database:

`-db or --guacdb`

Guacamole User:

`-gu or --guacuser`

Guacamole User Password:

`-gp or --guacpwd`

No MFA (No TOTP + Duo):

`-o or --nomfa`

Install TOTP:

`-t or --totp`

Install Duo:

`-d or --duo`

NOTE: Only the switches for MySQL Host, MySQL Port and Guacamole Database are available in the upgrade script.

## WARNING

- Upgrading from 0.9.14 or 1.1.0 to 1.3.0 has not been tested, only 1.2.0 to 1.3.0 has been tested.
- Switches have changed and additional ones have been added!

## How to Run:

### Download file directly from here:

`wget https://raw.githubusercontent.com/MysticRyuujin/guac-install/master/guac-upgrade.sh`

### Make it executable:

`chmod +x guac-upgrade.sh`

### Run it as root:

Interactive (asks for passwords):

`./guac-upgrade.sh`

Non-Interactive (MySQL root password provided via cli):

`./guac-upgrade.sh --mysqlpwd password`
