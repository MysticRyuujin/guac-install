

# guac-install

Script for installing Guacamole 1.1.0 on Ubuntu 16.04 or newer (with MySQL, or remote MySQL). It should also work on pure [Debian](https://www.debian.org/), [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) or [Kali Linux](https://www.kali.org/). I have tested this with Debian 10.3.0 (Buster). **If other versions don't work please open an issue.** It is likely due to a required library having a different name.

Run script, enter MySQL Root Password and Guacamole User password. Guacamole User is used to connect to the Guacamole Database.

The script attempts to install tomcat9 by default. It will fall back on tomcat8 **if the available version is 8.5.x or newer**, otherwise it will fall back to tomcat7. If you want to manually specify a tomcat version there's a commented out line you can modify. Have at it.

If you're looking to also have NGINX / Let's Encrypt / HTTPS click [HERE](https://github.com/bigredthelogger/guacamole)

## MFA/2FA

By default the script will not install MFA support (QR code for Google/Microsoft Authenticator, Duo Mobile, etc. or Duo Push), if you do want MFA support you need to specify the `-t` or `--totp` or for Duo `-d` or `--duo` flags on the command line. Or modify the script variables `installTOTP=true` or `installDuo=true`. **Do not install both**

## How to Run:

### Download file directly from here:

<code>wget https://git.io/fxZq5</code>

### Make it executable:

<code>chmod +x guac-install.sh</code>

### Run it as root:

Interactive (asks for passwords):

<code>./guac-install.sh</code>

Non-Interactive (values provided via cli):

<code>./guac-install.sh --mysqlpwd password --guacpwd password</code>

OR

<code>./guac-install.sh -r password -gp password</code>

Once installation is done you can access Guacamole by browsing to: http://<host_or_ip>:8080/guacamole/
The default credentials are guacadmin as both username and password. Please change them or disable guacadmin after install!

# guac-upgrade

Script for upgrading currently installed Guacamole instance (previously installed via this script/guide).  This will also now update the TOTP or Duo extensions if used.

If looks for the tomcat folder in /etc/ (E.G. `/etc/tomcat7` or `/etc/tomcat8`) hopefully that works to identify the correct tomcat version/path :smile: I'm open to suggestions/pull requests for a cleaner method.

## All Switches

Install MySQL:

<code>-i or --installmysql</code>

Do *NOT* install MySQL:

<code>-n or --nomysql</code>

MySQL Host:

<code>-h or --mysqlhost</code>

MySQL Port:

<code>-p or --mysqlport</code>

MySQL Root Password:

<code>-r or --mysqlpwd</code>

Guacamole Database:

<code>-db or --guacdb</code>

Guacamole User:

<code>-gu or --guacuser</code>

Guacamole User Password:

<code>-gp or --guacpwd</code>

Install TOTP:

<code>-t or --totp</code>

Install Duo:

<code>-d or --duo</code>

NOTE: Only the switches for MySQL Host, MySQL Port and Guacamole Database are available in the upgrade script.

## WARNING

- Upgrading from 0.9.14 -> 1.1.0 has not been tested, only 1.0.0 -> 1.1.0.
- Switches have changed and additional ones have been added!

## How to Run:

### Download file directly from here:

<code>wget https://raw.githubusercontent.com/MysticRyuujin/guac-install/master/guac-upgrade.sh</code>

### Make it executable:

<code>chmod +x guac-upgrade.sh</code>

### Run it as root:

Interactive (asks for passwords):

<code>./guac-upgrade.sh</code>

Non-Interactive (MySQL root password provided via cli):

<code>./guac-upgrade.sh --mysqlpwd password</code>
