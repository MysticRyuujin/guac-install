# guac-install

## NOTE: The version of FreeRDP2 that comes in the official repo for Ubuntu 18.04 is broken. If you are using Ubuntu 18.04 and RDP is not working / crashing run the following before or after install:
```
sudo add-apt-repository ppa:remmina-ppa-team/freerdp-daily
sudo apt-get update
sudo apt-get install freerdp2-dev freerdp2-x11
```

Script for installing Guacamole 1.1.0 on Ubuntu 16.04 or newer (with MySQL, or remote MySQL). It should also work on pure [Debian](https://www.debian.org/), [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) or [Kali Linux](https://www.kali.org/). I have tested this with Debian 10.3.0 (Buster). **If other versions don't work please open an issue.** It is likely due to a required library having a different name.

Run script, enter MySQL Root Password and Guacamole User password. Guacamole User is used to connect to the Guacamole Database.

The script attempts to install `tomcat9` by default (it will fall back on `tomcat8` **if the available version is 8.5.x or newer**, otherwise it will fall back to `tomcat7`). If you want to manually specify a tomcat version there's a commented out line you can modify. Have at it.

If you're looking to also have NGINX / Let's Encrypt / HTTPS click [HERE](https://github.com/bigredthelogger/guacamole)

## MFA/2FA

By default the script will not install MFA support (QR code for Google/Microsoft Authenticator, Duo Mobile, etc. or Duo Push), if you do want MFA support you can use the `-t` or `--totp` or for Duo `-d` or `--duo` flags on the command line. Or modify the script variables `installTOTP=true` or `installDuo=true`. **Do not install both**

## FYI

Here's a cool PowerShell module for using the Guacamole API: https://github.com/UpperM/guacamole-powershell

Does not work if you have MFA turned on (however, you can authenticate via the gui and get a token to use it that way)

## How to Run:

### Download file directly from here:

`wget https://git.io/fxZq5`

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

- Upgrading from 0.9.14 -> 1.1.0 has not been tested, only 1.0.0 -> 1.1.0.
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
