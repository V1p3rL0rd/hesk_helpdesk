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
dnf update -y

# Install EPEL repository
echo "Installing EPEL repository..."
dnf install -y epel-release

# Install required packages
echo "Installing required packages..."
dnf install -y httpd mysql-server php php-mysqlnd php-cli php-curl php-gd \
    php-mbstring php-xml php-xmlrpc unzip phpMyAdmin mod_ssl

# Start and enable services
echo "Starting and enabling services..."
systemctl enable --now httpd
systemctl enable --now mysqld

# Create self-signed SSL certificate
echo "Creating SSL certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_KEY" -out "$SSL_CERT" \
    -subj "/CN=$DOMAIN_NAME"

# Configure Apache
echo "Configuring Apache..."
cat > "/etc/httpd/conf.d/$DOMAIN_NAME.conf" << EOF
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

# Configure SELinux
echo "Configuring SELinux..."
setsebool -P httpd_can_network_connect on
setsebool -P httpd_can_network_relay on
chcon -R -t httpd_sys_content_t $WEB_ROOT

# Configure MySQL
echo "Configuring MySQL..."
mysql_secure_installation << EOF

y
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
y
y
y
y
EOF

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
chown -R apache:apache "$HESK_DIR"
chmod -R 755 "$HESK_DIR"

# Configure Apache for HESK
cat > "/etc/httpd/conf.d/hesk.conf" << EOF
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

    ErrorLog logs/hesk_error.log
    CustomLog logs/hesk_access.log combined
</VirtualHost>
EOF

# Configure firewall
echo "Configuring firewall..."
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Restart Apache
systemctl restart httpd

echo "HESK installation completed!"
echo "Please configure parameters in $HESK_DIR/hesk_settings.inc.php" 