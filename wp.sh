#!/bin/bash

apt update; apt-get install -y toilet bind9 wget mariadb-server mariadb-client apache2 php php-common php-mysql php-gmp php-curl php-intl php-mbstring php-xmlrpc php-gd php-xml php-cli php-zip
systemctl status mysql
echo "wait 2s";sleep 2
systemctl status apache2

sleep 5;clear
read -p 'Domain: example: wp.smk.net' domain
read -p 'Ip address, example: 192.168.1.69  : ' ip
IFS=. read ip1 ip2 ip3 ip4 <<< "$ip"
echo "$ip" >> /etc/resolv.conf;systemctl restart networking

mysql -u root --execute "CREATE DATABASE wordpress;
CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'Passw0rd';
GRANT ALL ON wordpress.* TO 'wp_user'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT";

cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xfzf latest.tar.gz; mv wordpress /var/www/html/
chown www-data:www-data /var/www/html/wordpress
chmod 755 /var/www/html/wordpress

cat <<EOT>> /etc/apache2/wp.conf
<VirtualHost *:80>
   ServerName $domain
   ServerAdmin admin@$domain
   DocumentRoot /var/www/html/wordpress

   ErrorLog ${APACHE_LOG_DIR}/wordpress_error.log
   CustomLog ${APACHE_LOG_DIR}/wordpress_access.log combined


   <Directory /var/www/html/wordpress>
      Options FollowSymlinks
      AllowOverride All
      Require all granted
   </Directory>

</VirtualHost>
EOT
a2dissite *;a2ensite wp.conf;systemctl reload apache2;

cat <<EOT>> /etc/bind/named.conf.local
        zone "$domain" {
             type master;
             file "/etc/bind/db.$domain";

	zone "$ip2.$ip1.in-addr.arpa" {
        type master;
        notify no;
        file "/etc/bind/rev.db.$domain";
};
EOT

cat <<EOT>> /etc/bind/db.$domain
$TTL    604800
@       IN      SOA     ns.$domain. root.$domain. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $domain.
@      IN      A       $ip

;also list other computers
;box     IN      A       192.168.1.21
EOT

systemctl restart bind9
sleep 2

cat <<EOT>> /etc/bind/rev.db.$domain

$TTL    604800
@       IN      SOA     $domain. root.$domain. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS	$domain.
$ip4.$ip3      IN      PTR     $domain.

EOT


