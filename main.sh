#!/bin/bash -i


read -p "your mikrotik local ip address,(ex: 10.10.x.1): " localip
read -p "your proxmox ip address,(ex: 10.12.x.2): " pxmip
read -p "your mikrotik on vlan ip address,(ex: 10.12.x.1): " mkip
read -p "your name, (ex: agos): " name
read -p "dns name, (ex: smkhooh.net): " fqdn




apt-get update --allow-releaseinfo-change
apt update
apt install php-fpm mariadb-server apache2 bind9 wget unzip php-mysql libapache2-mod-php -y
a2enmod proxy_fcgi setenvif
IFS=. read ip1 ip2 ip3 ip4 <<< "$pxmip"

mysql -u root --execute "CREATE DATABASE wordpress;
CREATE USER 'wp_user'@'localhost' IDENTIFIED BY '12345';
GRANT ALL ON wordpress.* TO 'wp_user'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT";

cd /tmp
wget https://wordpress.org/latest.zip
unzip latest.zip
sed -e "s,database_name_here,wordpress," -e "s,username_here,wp_user," -e "s,password_here,12345," wordpress/wp-config-sample.php > wordpress/wp-config.php
mv wordpress /var/www/html/

cd /etc/bind

cp db.local fwd.$name;
cp db.127 rev.$name;
cat <<EOT>> named.conf.default-zones
zone "$fqdn" {
	type master;
	file "/etc/bind/fwd.$name";
};
zone "$ip3.$ip2.$ip1.in-addr.arpa" {
	type master;
	file "/etc/bind/rev.$name";
};

EOT
#echo -e "zone '$fqdn' { type master; file '/etc/bind/fwd.$name'; };" >> named.conf.default-zones
#echo -e "zone '$ip3.$ip2.$ip1.in-addr.arpa' { type master; file '/etc/bind/rev.$name'; };" >> named.conf.default-zones

echo -e "@ IN A $pxmip" >> fwd.$name
echo -e "$ip4 IN PTR $fqdn." >> rev.$name
sed "s,localhost,$fqdn,g" fwd.$name -i
sed "s,localhost,$fqdn,g" rev.$name -i
echo -e "nameserver $pxmip \n search $fqdn \n nameserver 8.8.8.8" > /etc/resolv.conf

read -p "change apache2 document root to wordpress? Y/N: " ganti
if [[ $ganti == "Y" ]]; then
cd /etc/apache2/sites-available
sed "s,/html,/html/wordpress," 000-default.conf -i
a2dissite 000-default.conf
a2ensite 000-default.conf
fi


systemctl restart bind9
systemctl restart apache2
