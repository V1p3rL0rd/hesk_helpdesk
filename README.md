# HESK Help Desk Installation Scripts

This repository contains installation scripts for deploying HESK Help Desk system on Ubuntu 24.04 and RHEL 9.5.

## Prerequisites

- Ubuntu 24.04 or RHEL 9.5
- Root access
- HESK 3.5.2 ZIP file (hesk352.zip)
- Internet connection for package installation

## Features

- Automatic installation of all required packages
- Apache web server configuration with SSL support
- MySQL database setup
- HESK installation and configuration
- Security hardening
- SELinux configuration (for RHEL)
- Firewall configuration (for RHEL)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/hesk-installation.git
cd hesk-installation
```

2. Make the installation script executable:
```bash
# For Ubuntu
chmod +x install_hesk_ubuntu.sh

# For RHEL
chmod +x install_hesk_rhel.sh
```

3. Edit the configuration parameters in the script:
```bash
DOMAIN_NAME="example.com"
MYSQL_ROOT_PASSWORD="dbroot_12345"
HESK_DB_NAME="hesk"
HESK_DB_USER="hesk"
HESK_DB_PASSWORD="Hesk_12345"
```

4. Run the appropriate installation script:
```bash
# For Ubuntu
sudo ./install_hesk_ubuntu.sh

# For RHEL
sudo ./install_hesk_rhel.sh
```

## Post-Installation

1. Configure HESK settings in `$HESK_DIR/hesk_settings.inc.php`
2. Access your HESK installation at `https://your-domain.com`
3. Complete the web-based installation wizard

## Security Notes

- Change all default passwords after installation
- Keep your system and packages updated
- Regularly backup your database
- Consider using Let's Encrypt for SSL certificates in production

## Troubleshooting

### Common Issues

1. **Apache not starting**
   - Check Apache logs: `tail -f /var/log/apache2/error.log`
   - Verify SSL certificate permissions
   - Check port conflicts

2. **MySQL connection issues**
   - Verify MySQL service is running
   - Check user permissions
   - Verify database credentials

3. **SELinux issues (RHEL)**
   - Check SELinux logs: `tail -f /var/log/audit/audit.log`
   - Verify SELinux contexts

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- HESK Help Desk System
- Apache HTTP Server
- MySQL
- PHP 
