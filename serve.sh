#!/bin/bash
echo "############starting services############"

chown -R www-data:www-data /var/www/html
chmod -R 775 /var/www/html/storage

service php7.0-fpm start
service nginx start