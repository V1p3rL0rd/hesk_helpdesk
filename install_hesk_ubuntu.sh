#!/bin/bash

# Configuration parameters
DOMAIN_NAME="example.com"
MYSQL_ROOT_PASSWORD="dbroot_12345"
HESK_DB_NAME="hesk"
HESK_DB_USER="hesk"
HESK_DB_PASSWORD="Hesk_12345"
WEB_ROOT="/var/www/html"
HESK_DIR="/var/www/html/hesk"
SSL_CERT="/etc/ssl/certs/apache-selfsigned.crt"
SSL_KEY="/etc/ssl/private/apache-selfsigned.key"

# System update
echo "Updating system..."
apt update
apt upgrade -y

# Install required packages
echo "Installing required packages..."
apt install -y apache2 mysql-server php php-mysql libapache2-mod-php openssl \
    php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc unzip phpmyadmin

# Enable Apache modules
echo "Enabling Apache modules..."
a2enmod ssl rewrite

# Create self-signed SSL certificate
echo "Creating SSL certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_KEY" -out "$SSL_CERT" \
    -subj "/CN=$DOMAIN_NAME"

# Configure Apache
echo "Configuring Apache..."
cat > "/etc/apache2/sites-available/$DOMAIN_NAME.conf" << EOF
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    Redirect / https://$DOMAIN_NAME/
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN_NAME
    DocumentRoot $WEB_ROOT

    SSLEngine on
    SSLCertificateFile $SSL_CERT
    SSLCertificateKeyFile $SSL_KEY

    <Directory $WEB_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Enable site configuration
a2ensite "$DOMAIN_NAME.conf"
a2dissite 000-default.conf

# Restart Apache
systemctl restart apache2

# Configure MySQL
echo "Configuring MySQL..."
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

# Create HESK database and user
echo "Creating HESK database..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $HESK_DB_NAME;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS '$HESK_DB_USER'@'localhost' IDENTIFIED BY '$HESK_DB_PASSWORD';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON $HESK_DB_NAME.* TO '$HESK_DB_USER'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

# Extract HESK
echo "Installing HESK..."
cp hesk352.zip /tmp/
unzip -o /tmp/hesk352.zip -d "$WEB_ROOT"

# Set permissions
chown -R www-data:www-data "$HESK_DIR"

# Configure Apache for HESK
cat > "/etc/apache2/sites-available/hesk.conf" << EOF
<VirtualHost *:443>
    ServerName $DOMAIN_NAME
    DocumentRoot $HESK_DIR

    SSLEngine on
    SSLCertificateFile $SSL_CERT
    SSLCertificateKeyFile $SSL_KEY

    <Directory $HESK_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable HESK configuration
a2ensite hesk.conf

# Final Apache restart
systemctl restart apache2

echo "HESK installation completed!"
echo "Please configure parameters in $HESK_DIR/hesk_settings.inc.php" 