# guac-install

Script for installing Guacamole 1.1.0 on Ubuntu 16.04 or newer with MySQL. It should also work on pure Debian 7, 8, and 9. **It seems Debian 10 is not working right now**

Run script, enter MySQL Root Password and Guacamole User password. Guacamole User is used to connect to the Guacamole Database.

The script attempts to install tomcat8 if the available version is 8.5.x or newer, if tomcat8 is only 8.0.x it will fall back to tomcat7. If you want to manually specify a tomcat version there's a commented out line you can modify at line #73. Have at it.

If you're looking to also have NGINX / Let's Encrypt / HTTPS click [HERE](https://github.com/bigredthelogger/guacamole)

## MFA/2FA

By default the script will not install MFA support (QR code for Google/Microsoft Authenticator, Duo Mobile, etc. or Duo Push), if you do want MFA support you need to specify the `-t` or `--totp` or for Duo `-o` or `--duo` flags on the command line. Or modify the script variable `installTOTP=true` or `installDuo=true`

## How to Run:

### Download file directly from here:

<code>wget https://git.io/fxZq5</code>

### Make it executable:

<code>chmod +x guac-install.sh</code>

### Run it as root:

Interactive (asks for passwords):

<code>./guac-install.sh</code>

Non-Interactive (passwords provided via cli):

<code>./guac-install.sh --mysqlpwd password --guacpwd password</code>

OR

<code>./guac-install.sh -m password -g password</code>

Once installation is done you can access guacamole by browsing to: http://<host_or_ip>:8080/guacamole/
The default credentials are guacadmin as both username and password. Please change them or disable guacadmin after install!

# guac-upgrade
Script for upgrading currently installed Guacamole instance (previously installed via this script/guide)


If looks for the tomcat folder in /etc/ (E.G. `/etc/tomcat7` or `/etc/tomcat8`) hopefully that works to identify the correct tomcat version/path :smile: I'm open to suggestions/pull requests for a cleaner method.

## WARNING

I don't think this script is working anymore. Way too many reports that 0.9.14 -> 1.0.0 are not working. I don't know why.

## How to Run:

### Download file directly from here:

<code>wget https://raw.githubusercontent.com/MysticRyuujin/guac-install/master/guac-upgrade.sh</code>

### Make it executable:

<code>chmod +x guac-upgrade.sh</code>

### Run it as root:

Interactive (asks for passwords):

<code>./guac-upgrade.sh</code>

Non-Interactive (password provided via cli):

<code>./guac-upgrade.sh --mysqlpwd password</code>
