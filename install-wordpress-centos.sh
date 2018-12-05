#!/bin/bash

#######################################
# Bash script to install WordPress on CentOS
# Author: Subhash (serverkaka.com)

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# prerequisite
yum install -y wget

## check Current directory
pwd=$(pwd)

# Ask value for mysql root password and DB name
read -p 'wordpress_db_name [wp_db]: ' wordpress_db_name
read -p 'db_root_password [secretpasswd]: ' db_root_password
echo

# Install APache
# Install APache
yum install -y httpd
systemctl start httpd

# Set apache autostart at system reboot
sudo systemctl enable httpd

# Allow Apache via Firewall
firewall-cmd --permanent --add-service=http
systemctl restart firewalld

# Install PHP
yum install php php-mysql php-pdo php-gd php-mbstring -y

# Install MySql
# Removing previous mysql server installation
systemctl stop mysqld.service && yum remove -y mysql-community-server && rm -rf /var/lib/mysql && rm -rf /var/log/mysqld.log && rm -rf /etc/my.cnf

# Installing mysql server (community edition)'
yum localinstall -y https://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm
yum install -y mysql-community-server

# Starting mysql server (first run)'
systemctl enable mysqld.service
systemctl start mysqld.service
tempRootDBPass="`grep 'temporary.*root@localhost' /var/log/mysqld.log | tail -n 1 | sed 's/.*root@localhost: //'`"

# Setting up new mysql server root password'
systemctl stop mysqld.service
rm -rf /var/lib/mysql/*logfile*
wget -O /etc/my.cnf "https://my-site.com/downloads/mysql/512MB.cnf"
systemctl start mysqld.service
mysqladmin -u root --password="$tempRootDBPass" password "$db_root_password"
mysql -u root --password="$db_root_password" -e <<-EOSQL
    DELETE FROM mysql.user WHERE User='';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    DELETE FROM mysql.user where user != 'mysql.sys';
    CREATE USER 'root'@'%' IDENTIFIED BY '${mysqlRootPass}';
    GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
EOSQL
systemctl status mysqld.service

## Install Latest WordPress
rm /var/www/html/index.*
wget -c http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
rsync -av wordpress/* /var/www/html/

# Set Permissions
chmod -R 755 /var/www/html/

## Configure WordPress Database
mysql -uroot -p$db_root_password <<QUERY_INPUT
CREATE DATABASE $wordpress_db_name;
GRANT ALL PRIVILEGES ON $wordpress_db_name.* TO 'root'@'localhost' IDENTIFIED BY '$db_root_password';
FLUSH PRIVILEGES;
EXIT
QUERY_INPUT

## Add Database Credentias in wordpress
cd /var/www/html/
sudo mv wp-config-sample.php wp-config.php
perl -pi -e "s/database_name_here/$wordpress_db_name/g" wp-config.php
perl -pi -e "s/username_here/root/g" wp-config.php
perl -pi -e "s/password_here/$db_root_password/g" wp-config.php

## Restart Apache and Mysql
systemctl restart httpd
systemctl restart mysqld.service

## Cleaning Download
cd $pwd
rm -rf latest.tar.gz wordpress

echo "Installation is complete."
