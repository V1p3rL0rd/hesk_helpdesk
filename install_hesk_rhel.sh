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
apache_cert_dir="/etc/pki/tls"
firewall_ports=("22/tcp" "443/tcp")

# Check if HESK archive exists
if [ ! -f hesk352.zip ]; then
    echo "Error: hesk352.zip not found in current directory!"
    echo "Please place hesk352.zip in the same directory as this script."
    exit 1
fi

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install EPEL repository
echo "Installing EPEL repository..."
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

# Enable CodeReady Builder repository
echo "Enabling CodeReady Builder repository..."
subscription-manager repos --enable codeready-builder-for-rhel-9-x86_64-rpms

# Install required packages
echo "Installing required packages..."
dnf install -y httpd mysql-server mysql php php-mysqlnd php-gd php-xml php-bcmath \
    php-mbstring php-ldap php-zip mod_ssl openssl unzip

# Create Apache user if not exists
if ! id -u apache >/dev/null 2>&1; then
    useradd -r -s /sbin/nologin apache
fi

# Create web root directory
echo "Creating web root directory..."
mkdir -p /var/www/html
chown apache:apache /var/www/html
chmod 755 /var/www/html

# Start MySQL
echo "Starting MySQL service..."
systemctl enable --now mysqld

# Wait for MySQL to start
echo "Waiting for MySQL to start..."
sleep 10

# Configure MySQL security
echo "Configuring MySQL security..."
mysql_secure_installation <<EOF

y
${mysql_root_pass}
${mysql_root_pass}
y
y
y
y
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
FLUSH PRIVILEGES;
EOF

# Extract HESK
echo "Extracting HESK..."
cp hesk352.zip /tmp/
unzip -o /tmp/hesk352.zip -d /var/www/html/
rm -f /tmp/hesk352.zip

# Set permissions
echo "Setting permissions..."
chown -R apache:apache /var/www/html
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
sed -i "s|^SSLCertificateFile .*|SSLCertificateFile ${apache_cert_dir}/certs/hesk.crt|" /etc/httpd/conf.d/ssl.conf
sed -i "s|^SSLCertificateKeyFile .*|SSLCertificateKeyFile ${apache_cert_dir}/private/hesk.key|" /etc/httpd/conf.d/ssl.conf

# Configure timezone
echo "Configuring timezone..."
sed -i "s/^;*\s*date\.timezone\s*=.*/date.timezone = Europe\/Moscow/" /etc/php.ini

# Configure Firewall
echo "Configuring firewall..."
for port in "${firewall_ports[@]}"; do
    firewall-cmd --permanent --add-port=${port}
done
firewall-cmd --reload

# Configure SELinux
echo "Configuring SELinux..."
setsebool -P httpd_can_network_connect 1
setsebool -P httpd_can_network_relay 1
setsebool -P httpd_unified 1

# Start services
echo "Starting services..."
systemctl enable --now httpd mysqld

# Final information
echo "HESK has been successfully installed!"
echo "To access the web interface: https://$(hostname -f)"
echo "MySQL root password is stored in: /root/mysql_root_password.txt"
echo "Database parameters:"
echo "  Database: ${mysql_db}"
echo "  User: ${mysql_user}"
echo "  Password: ${mysql_pass}" 
