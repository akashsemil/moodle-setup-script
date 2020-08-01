#!/bin/bash
#
# Script was created by: Akash Semil <semil19@hotmail.com>
# github.com/akashsemil
#
# Customize your moodle installation by modifying the variables below
# Variables: 
# Moodle Data Directory
MOODLE_DATA_DIR="/var/moodle-data"
# SQL root user password
DB_ROOT_PASSWORD="rootpassword"
# Moodle database name
MOODLE_DB_NAME="moodle"
# Moodle database user & password
MOODLE_DB_USER="moodle"
MOODLE_DB_USER_PASSWD="moodlepassword"
#
# EXIT Values
# 0				Success
# 1 			Run as Root
# 2				Unsupported OS (only for centos 7, 8)
# 3				Package Installation Failed
# 4				Service Failed (httpd or mariadb)
# 5				Unable to configure database
# 6				Unable to download and install moodle
#
function package_installation
{
	# EPEL & Remi Repo required for centos 7
	if [ $VERSION_ID -eq 7 ]
	then
		#Adding Remi Repo & Installing yum-utils & Enabling php72
		if yum install -y epel-release &> script.out &&
		   yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm &> script.out &&
		   yum install -y yum-utils &> script.out &&
		   yum-config-manager --enable remi-php72 &> script.out &&
		   echo "# MariaDB 10.5 CentOS repository list - created 2020-07-11 12:40 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name=MariaDB
baseurl=http://yum.mariadb.org/10.5/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
enabled=1" > /etc/yum.repos.d/MariaDB.repo
			   yum install -y wget gzip httpd php72 mariadb-server mod_php php-posix php-mysqlnd php-mbstring php-intl php-zip php-dom php-gd php-xml php-xmlrpc php-soap php-opcache php-json &> script.out
		then
			echo -e "\e[32mStatus: Package Installed Successfully"
		else
			echo -e "\e[31mError: Package Installation Failed"
			exit 3
		fi
	elif [ $VERSION_ID -eq 8 ]
	then
		if yum install -y wget gzip httpd php mariadb-server mod_php php-posix php-mysqlnd php-mbstring php-intl php-zip php-dom php-gd php-xml php-xmlrpc php-soap php-opcache php-json &> script.out
		then
			echo -e "\e[32mStatus: Package Installed Successfully"
		else
			echo -e "\e[31mError: Package Installation Failed"
			exit 3
		fi
	fi
}
function managing_services
{
	# starting and enabling services
	if systemctl enable httpd --now &> script.out && 
		systemctl enable mariadb --now &> script.out
	then
		echo -e "\e[32mStatus: Services started successfully"
	else
		echo -e "\e[31mError: Unable to start the services"
		exit 4
	fi
}
function database_configuration
{
	# database configuration
	if $(mysqladmin password "$DB_ROOT_PASSWORD") &> script.out
	then
		mysql -uroot -p$DB_ROOT_PASSWORD <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
CREATE DATABASE $MOODLE_DB_NAME;
CREATE USER '$MOODLE_DB_USER'@'localhost' IDENTIFIED BY '$MOODLE_DB_USER_PASSWD';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON $MOODLE_DB_NAME.* TO '$MOODLE_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
		echo -e "\e[32mStatus: Database configured"
	else
		echo -e "\e[31mError: Unable to configure database"
		exit 5
	fi
}
function installing_moodle
{
	# downloading and setting up moodle
	if wget -P /tmp https://download.moodle.org/download.php/direct/stable39/moodle-3.9.tgz &> script.out &&
		tar -xf /tmp/moodle-3.9.tgz -C /var/www/html/ &&
		chown root:root -R /var/www/html/moodle &&
		mkdir $MOODLE_DATA_DIR &&
		chown apache:apache $MOODLE_DATA_DIR &&
		chmod 700 $MOODLE_DATA_DIR &&
		restorecon -RF /var/www/html/
	then
		echo -e "\e[32mStatus: Moodle Installed"
	else
		echo -e "\e[31mError: Moodle Installation Failed"
		exit 6
	fi
}
function configuring_firewall
{
	if firewall-cmd --permanent --add-service http &> script.out &&
		firewall-cmd --reload &> script.out
	then
		echo -e "\e[32mStatus: Firewall HTTP rule added successfully"
	else
		echo -e "\e[31mError: Unable to add firewall rules"
	fi
}
function finish
{
	echo -e  "\e[32mFinish: Script Completed Successfully"
	echo -e "\e[93m"
	echo "Instruction: Open up the following url in your browser: http://localhost/moodle or http://MACHINE_IP/moodle or http://FQDN/moodle"
	echo "Initial Configuration"
	echo " -> Choose a Language: English(en) -> Next"
	echo " -> Data Directory: $MOODLE_DATA_DIR -> Next"
	echo " -> Choose Database Drive: MariaDB -> Next"
	echo " -> Database Host: localhost"
	echo " -> Database Name: $MOODLE_DB_NAME"
	echo " -> Database User: $MOODLE_DB_USER"
	echo " -> Database Password: $MOODLE_DB_USER_PASSWD"
	echo " -> Table Prefix: mdl_"
	echo " -> Database Port: 3306"
	echo " -> Unix Socket: /var/lib/mysql/mysql.sock -> Next"
	echo " -> Copy the configuration and save it in /var/www/html/moodle/config.php -> Next -> Next -> Continue\n"
	echo -e "\e[32mComplete the configuration and your moodle server will be up and running"
}
if [ $(whoami) == "root" ]
then
	clear
    source /etc/os-release
	if [ "$ID" == "centos" ]
	then
		echo "INFO: Script is running (it will take some time depends on your net connection).Have a coffee Break."
		echo -e "\e[32mStatus: OS Detected: $ID $VERSION_ID"
		package_installation
		managing_services
		database_configuration
		installing_moodle
		configuring_firewall
		finish
    else
        echo -e "\e[31mError: Unsupported Distribution"
        exit 2
	fi
else
	echo -e "\e[31mError: Run script as root."
	exit 1
fi
echo -e "\e[0m"
