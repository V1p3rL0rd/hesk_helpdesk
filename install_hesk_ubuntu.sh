#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
   echo "Warning! This script must be run as root!"
   exit 1
fi

# Configuration variables
mysql_db="hesk"
mysql_user="hesk"
mysql_pass="hesk_password"
mysql_root_pass=$(openssl rand -base64 24)
apache_cert_dir="/etc/ssl"
firewall_ports=("22/tcp" "443/tcp")

# Check if HESK archive exists
if [ ! -f hesk352.zip ]; then
    echo "Error: hesk352.zip not found in current directory!"
    echo "Please place hesk352.zip in the same directory as this script."
    exit 1
fi

# Update system packages
echo "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "Installing required packages..."
apt install -y apache2 mysql-server php php-mysql php-gd php-xml php-bcmath \
    php-mbstring php-ldap php-zip libapache2-mod-php unzip

# Create web root directory
echo "Creating web root directory..."
mkdir -p /var/www/html
chown www-data:www-data /var/www/html
chmod 755 /var/www/html

# Start MySQL
echo "Starting MySQL service..."
systemctl enable --now mysql

# Wait for MySQL to start
echo "Waiting for MySQL to start..."
sleep 10

# Set root password and secure MySQL
echo "Configuring MySQL security..."
mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_pass}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Create MySQL configuration file for root user access
cat > /root/.my.cnf <<EOF
[client]
user=root
password=${mysql_root_pass}
EOF
chmod 600 /root/.my.cnf

# Save MySQL root password to file with restricted access (root only)
echo "MySQL root password: ${mysql_root_pass}" > /root/mysql_root_password.txt
chmod 600 /root/mysql_root_password.txt

# Create database and user for HESK
echo "Creating database and user for HESK..."
mysql --defaults-extra-file=/root/.my.cnf <<EOF
CREATE DATABASE ${mysql_db} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER '${mysql_user}'@'localhost' IDENTIFIED BY '${mysql_pass}';
GRANT ALL PRIVILEGES ON ${mysql_db}.* TO '${mysql_user}'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON ${mysql_db}.* TO '${mysql_user}'@'localhost';
GRANT CREATE TEMPORARY TABLES ON ${mysql_db}.* TO '${mysql_user}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Verify MySQL user permissions
echo "Verifying MySQL user permissions..."
mysql --defaults-extra-file=/root/.my.cnf -e "SHOW GRANTS FOR '${mysql_user}'@'localhost';"

# Extract HESK
echo "Extracting HESK..."
cp hesk352.zip /tmp/
unzip -o /tmp/hesk352.zip -d /var/www/html/
rm -f /tmp/hesk352.zip

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
mkdir -p /var/www/html/attachments
mkdir -p /var/www/html/cache
chmod -R 777 /var/www/html/attachments
chmod -R 777 /var/www/html/cache

# Generate self-signed SSL certificate
echo "Generating self-signed SSL certificate..."
mkdir -p ${apache_cert_dir}/{certs,private}
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout ${apache_cert_dir}/private/hesk.key \
   -out ${apache_cert_dir}/certs/hesk.crt \
   -subj "/C=AB/ST=Sukhum Dist./L=Sukhum/O=SBRA/CN=hesk.local"

# Configure SSL for Apache
echo "Configuring SSL for Apache..."
a2enmod ssl
cat > /etc/apache2/sites-available/hesk.conf <<EOF
<VirtualHost *:443>
    ServerName $(hostname -f)
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile ${apache_cert_dir}/certs/hesk.crt
    SSLCertificateKeyFile ${apache_cert_dir}/private/hesk.key

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/hesk_error.log
    CustomLog \${APACHE_LOG_DIR}/hesk_access.log combined
</VirtualHost>
EOF
a2ensite hesk.conf

# Configure timezone
echo "Configuring timezone..."
sed -i "s/^;*\s*date\.timezone\s*=.*/date.timezone = Europe\/Moscow/" /etc/php/*/apache2/php.ini

# Configure Firewall
echo "Configuring firewall..."
ufw allow 22/tcp
ufw allow 443/tcp
ufw --force enable

# Start services
echo "Starting services..."
systemctl enable --now apache2 mysql

# Final information
echo "HESK has been successfully installed!"
echo "To complete the installation, please follow these steps:"
echo "1. Access the installation wizard at: https://hesk_IP/install/"
echo "2. Follow the installation wizard steps"
echo "3. Use the following database parameters when prompted:"
echo "   Database: ${mysql_db}"
echo "   User: ${mysql_user}"
echo "   Password: ${mysql_pass}"
echo "4. After installation is complete, delete the 'install' directory"
echo "5. MySQL root password is stored in: /root/mysql_root_password.txt"
