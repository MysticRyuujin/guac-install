# guac-install
Script for installing Guacamole 0.9.13 on Ubuntu 16.04 with MySQL. Should also work on pure Debian.

Run script, enter MySQL Root Password and Guacamole User password. Guacamole User is used to connect to the Guacamole Database.

The script attempts to install tomcat8, if that's not in apt-cache it will attempt to install tomcat7, then tomcat6. If you want to manually specify a tomcat version there's a commented out line you can modify. Have at it.

How to Run:

Download file directly from here:

<code>wget https://raw.githubusercontent.com/MysticRyuujin/guac-install/master/guac-install.sh</code>

Make it executable:

<code>chmod +x guac-install.sh</code>

Run it as root:

<code>./guac-install.sh</code>

Once installation is done you can access guacamole by browsing to: http://<host_or_ip>:8080/guacamole/
The default credentials are guacadmin as both username and password. Please change them or disable guacadmin after install!
