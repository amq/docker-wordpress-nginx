# A LEMP stack with SSH
# Big thanks to jbfink and eugeneware

FROM ubuntu:14.04
MAINTAINER amq <https://github.com/amq>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

RUN \
apt-get update && \
apt-get -y upgrade && \
apt-get -y install nginx mysql-server curl git unzip pwgen python-setuptools openssh-server && \
apt-get -y install php5-fpm php5-mysql php5-curl php5-gd php5-mcrypt php-pear php-soap && \
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Keep upstart from complaining
RUN \
dpkg-divert --local --rename --add /sbin/initctl && \
ln -sf /bin/true /sbin/initctl && \
mkdir /var/run/sshd

RUN \
useradd -m -G sudo -s /bin/bash www && \
sed -i -e "s/PermitRootLogin\syes/PermitRootLogin no/g" /etc/ssh/sshd_config && \
sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/expose_php\s*=\s*On/expose_php = Off/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/max_execution_time\s*=\s*30/max_execution_time = 60/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf

# Nginx config
ADD ./nginx.conf /etc/nginx/nginx.conf
ADD ./nginx-site.conf /etc/nginx/sites-enabled/default

# PHP-FPM pool config
ADD ./fpm-www.conf /etc/php5/fpm/pool.d/www.conf

# MySQL config
ADD ./my.cnf /etc/mysql/my.cnf

# Supervisor config
RUN /usr/bin/easy_install supervisor && /usr/bin/easy_install supervisor-stdout
ADD ./supervisord.conf /etc/supervisord.conf

# Install Wordpress
RUN \
wget http://wordpress.org/latest.tar.gz -O /srv/latest.tar.gz && \
cd /srv && tar xvf latest.tar.gz && rm latest.tar.gz && \
mv /srv/wordpress /srv/www && \
chown -R www:www /srv/www

# Install Adminer
RUN \
mkdir /srv/www/adminer && \
wget http://sourceforge.net/projects/adminer/files/latest/download -O /srv/www/adminer/adminer.php && \
wget https://raw.github.com/vrana/adminer/master/designs/pepa-linha/adminer.css -O /srv/www/adminer/adminer.css && \
chown www:www -R /srv/www/adminer

# Initialization and startup script
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

VOLUME ["/srv", "/var/lib/mysql", "/var/log/nginx"]

# Private expose
EXPOSE 22
EXPOSE 3306
EXPOSE 80

CMD ["/bin/bash", "/start.sh"]
