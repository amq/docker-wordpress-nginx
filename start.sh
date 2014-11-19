#!/bin/bash

# SSH user password persistency
# Also prints out the passwords on each container start
if [ -f /srv/ssh-www-pw.txt ]; then

  SSH_PASSWORD=`cat /srv/ssh-www-pw.txt`
  MYSQL_PASSWORD=`cat /srv/mysql-root-pw.txt`
  WORDPRESS_PASSWORD=`cat /srv/mysql-wordpress-pw.txt`
  printf "\n"
  echo "www:$SSH_PASSWORD" | chpasswd
  echo "Password for SSH www user:" $SSH_PASSWORD
  echo "Password for MySQL root user:" $MYSQL_PASSWORD
  echo "Password for MySQL wordpress user:" $WORDPRESS_PASSWORD
  printf "\n"

fi

# Configure Wordpress
if [ ! -f /srv/www/wp-config.php ]; then

  SSH_PASSWORD=`pwgen -c -n -1 12`
  MYSQL_PASSWORD=`pwgen -c -n -1 12`
  WORDPRESS_PASSWORD=`pwgen -c -n -1 12`
  printf "\n"
  echo "www:$SSH_PASSWORD" | chpasswd
  echo "Password for SSH www user:" $SSH_PASSWORD
  echo "Password for MySQL root user:" $MYSQL_PASSWORD
  echo "Password for MySQL wordpress user:" $WORDPRESS_PASSWORD
  printf "\n"
  echo $WORDPRESS_PASSWORD > /srv/ssh-www-pw.txt
  echo $MYSQL_PASSWORD > /srv/mysql-root-pw.txt
  echo $WORDPRESS_PASSWORD > /srv/mysql-wordpress-pw.txt

  WORDPRESS_DB="wordpress"

  #mysql has to be started this way as it doesn't work to call from /etc/init.d
  /usr/bin/mysqld_safe &
  sleep 10s

  sed -e "s/database_name_here/$WORDPRESS_DB/
  s/username_here/$WORDPRESS_DB/
  s/password_here/$WORDPRESS_PASSWORD/
  /'AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'SECURE_AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'LOGGED_IN_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'NONCE_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'SECURE_AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'LOGGED_IN_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'NONCE_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/" /srv/www/wp-config-sample.php > /srv/www/wp-config.php

  # Download nginx helper plugin
  curl -O `curl -i -s https://wordpress.org/plugins/nginx-helper/ | egrep -o "https://downloads.wordpress.org/plugin/[^']+"`
  unzip -o nginx-helper.*.zip -d /srv/www/wp-content/plugins
  chown -R www-data:www-data /srv/www/wp-content/plugins/nginx-helper

  # Activate nginx plugin and set up pretty permalink structure once logged in
  cat << ENDL >> /srv/www/wp-config.php
\$plugins = get_option( 'active_plugins' );
if ( count( \$plugins ) === 0 ) {
  require_once(ABSPATH .'/wp-admin/includes/plugin.php');
  \$wp_rewrite->set_permalink_structure( '/%postname%/' );
  \$pluginsToActivate = array( 'nginx-helper/nginx-helper.php' );
  foreach ( \$pluginsToActivate as \$plugin ) {
    if ( !in_array( \$plugin, \$plugins ) ) {
      activate_plugin( '/srv/www/wp-content/plugins/' . \$plugin );
    }
  }
}
ENDL

  chown www:www /srv/www/wp-config.php

  mysqladmin -u root password $MYSQL_PASSWORD
  mysql -uroot -p$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
  mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE wordpress; GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost' IDENTIFIED BY '$WORDPRESS_PASSWORD'; FLUSH PRIVILEGES;"
  killall mysqld
fi

# start all the services
/usr/local/bin/supervisord -n
