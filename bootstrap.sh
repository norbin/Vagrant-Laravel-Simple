#!/usr/bin/env bash

sed -i 's/^mesg n$/tty -s \&\& mesg n/g' /root/.profile

#variables
area="Europe"
zone="Budapest"
projectname='vagrant'
database='vagrant'
username='vagrant'
password='vagrant'

echo ''
echo '################################################################'
echo '#            Install Laravel Development Environment           #'
echo '#                                                              #'
echo '#   PHP 5.4, Apache2.2.22, Mysql, Git, cURL, Xdebug, Laravel   #'
echo '#                                                              #'
echo '################################################################'
echo ''

echo 'Configuring Timezone'
#Set time zone and time
echo "tzdata tzdata/Areas select $area" | debconf-set-selections
echo "tzdata tzdata/Zones/$area select $zone" | debconf-set-selections
echo $area/$zone > /etc/timezone
cp /usr/share/zoneinfo/$area/$zone /etc/localtime
/usr/sbin/ntpdate pool.ntp.org
dpkg-reconfigure --frontend noninteractive tzdata

echo 'Update and Upgrade Repositories this takes a while....'
apt-get update >/dev/null
sudo apt-get upgrade -y >/dev/null
echo '...done'

echo 'Install Vim'
apt-get install -y vim >/dev/null 2>&1
echo '...done'
##########################################
# PHP 5.4
##########################################
echo 'Install PHP 5.4'
apt-get install -y python-software-properties >/dev/null
echo '...done'
echo 'Adding PHP 5.4 PPA'
add-apt-repository ppa:ondrej/php5 >/dev/null 2>&1
apt-get update >/dev/null
echo '...done'
echo 'Install dependencies'
apt-get install -y php5 >/dev/null
apt-get install -y php5-mcrypt >/dev/null
apt-get install -y php5-mysql >/dev/null
apt-get install -y php5-curl >/dev/null
apt-get install -y php5-cli >/dev/null
#Error Reporting
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/cli/php.ini
#Memory Limit
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/cli/php.ini
#timezone
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/cli/php.ini
echo '...done'

##########################################
# Apache 2.2.22
##########################################
echo 'Install Apache2.2.22'
apt-get install -y apache2 >/dev/null
sed -i "s/#ServerRoot.*/ServerName localhost/" /etc/apache2/apache2.conf
a2enmod rewrite >/dev/null
echo 'Setting up Apache2 virtual host'
rm -rf /var/www
ln -fs /vagrant /var/www

VHOST=$(cat <<EOF
<VirtualHost *:80>
	ServerName localhost
	DocumentRoot /var/www/$projectname/public
	<Directory />
		Options FollowSymLinks
		AllowOverride All
	</Directory>
	<Directory /var/www/>
		Options +Indexes +FollowSymLinks +MultiViews
		AllowOverride All
		Require all granted 
	</Directory>
	ErrorLog ${APACHE_LOG_DIR}/error.log
	LogLevel warn
	CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
)

echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf

a2ensite 000-default >/dev/null
echo 'Apache2 run as vagrant user'
sed -i '/export APACHE_RUN_USER=www-data/c\export APACHE_RUN_USER=vagrant' /etc/apache2/envvars
sed -i '/export APACHE_RUN_GROUP=www-data/c\export APACHE_RUN_GROUP=vagrant' /etc/apache2/envvars
service apache2 reload >/dev/null
echo '...done'
#############################################
# Mysql 5.5
#############################################
# Ignore install questions
echo 'Install Mysql-Server-5.5'
export DEBIAN_FRONTEND=noninteractive
apt-get install -y mysql-server-5.5 >/dev/null
sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
service mysql restart
echo 'Create user and database'
echo "CREATE DATABASE IF NOT EXISTS $database" | mysql
echo "CREATE USER '$username'@'localhost' IDENTIFIED BY '$password'" | mysql
echo "GRANT ALL PRIVILEGES ON $database.* TO '$username'@'localhost' IDENTIFIED BY '$password'" | mysql
echo '...done'

#############################################
# git cURL Composer
#############################################
echo 'Install Git, cURL, Composer'
apt-get install -y curl >/dev/null
apt-get install -y git >/dev/null
curl -s https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
echo '...done'

cd /var/www
composer create-project laravel/laravel $projectname --prefer-dist
chmod -R 777 /var/www/$projectname/app/storage

echo 'Create app/config/database.php'

DATABASE=$(cat <<EOF
<?php
	return array(
		'fetch' => PDO::FETCH_CLASS,
		'default' => 'mysql',
		'connections' => array(
			'mysql' => array(
				'driver' => 'mysql',
				'host' => 'localhost',
				'database' => $database,
				'username' => $username,
				'password' => $password,
				'charset' => 'utf8',
				'collation' => 'utf8_unicode_ci',
				'prefix' => '',
			),
		),
	);
EOF
)

echo "$DATABASE" > /var/www/$projectname/app/config/database.php

echo ''
echo "###################################################################"
echo '#                         Installation done                       #'
echo '#                      Open http://localhost:4444                 #'
echo '###################################################################'
