# guac-install
Script for installing Guacamole 0.9.14 on Ubuntu 16.04 or newer with MySQL. It should also work on pure Debian >= 7 but I have not tested. Feel free to provide freeback!

Run script, enter MySQL Root Password and Guacamole User password. Guacamole User is used to connect to the Guacamole Database.

The script attempts to install tomcat8 if the available version is 8.5.x or newer, if tomcat8 is only 8.0.x it will fall back to tomcat7. If you want to manually specify a tomcat version there's a commented out line you can modify at line #73. Have at it.

NOTE: It seems like a lot of people have issues with Tomcat8 for some reason so I removed it from the script. If you're using Tomcat8 and it's working yay, you can keep using it by forcing it via the commented out line.

How to Run:

Download file directly from here:

<code>wget https://raw.githubusercontent.com/MysticRyuujin/guac-install/master/guac-install.sh</code>

Make it executable:

<code>chmod +x guac-install.sh</code>

Run it as root:

<code>./guac-install.sh</code>

Once installation is done you can access guacamole by browsing to: http://<host_or_ip>:8080/guacamole/
The default credentials are guacadmin as both username and password. Please change them or disable guacadmin after install!

# guac-upgrade
Script for upgrading currently installed Guacamole instance (previously installed via this script/guide)

How to Run:

Download file directly from here:

<code>wget https://raw.githubusercontent.com/MysticRyuujin/guac-install/master/guac-upgrade.sh</code>

Make it executable:

<code>chmod +x guac-upgrade.sh</code>

Run it as root:

<code>./guac-upgrade.sh</code>
