FROM ubuntu:latest

RUN apt-get -y --force-yes  update && apt-get install -y nginx && apt-get -y --force-yes install php7.0-fpm  && apt-get -y --force-yes install php-fpm php-mysql php-mbstring

RUN echo "daemon off;" >> /etc/nginx/nginx.conf

ADD default /etc/nginx/sites-enabled/

ADD . /var/www/html/

CMD ["bash", "/var/www/html/serve.sh"]