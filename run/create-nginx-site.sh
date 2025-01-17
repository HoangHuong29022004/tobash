#!/bin/bash

# Colors
NORMAL="\\033[0;39m"
GREEN="\\033[1;32m"
RED="\\033[1;31m"
BLUE="\\033[1;34m"
ORANGE="\\033[1;33m"

# Function to check if command executed successfully
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NORMAL}"
    else
        echo -e "${RED}✗ $1${NORMAL}"
        return 1
    fi
}

echo -e "${BLUE}=== Create Virtual Host ===${NORMAL}"

# Get PHP version
echo -e "${BLUE}Available PHP versions:${NORMAL}"
ls /usr/sbin/php-fpm* | grep -o 'php-fpm[0-9.]*' | sort
read -p "Enter PHP version (e.g., 8.2): " PHP_VERSION

# Validate PHP version
if [ ! -f "/usr/sbin/php-fpm$PHP_VERSION" ]; then
    echo -e "${RED}PHP-FPM version $PHP_VERSION not found!${NORMAL}"
    exit 1
fi

# Get domain name and validate
read -p "Enter domain name: " DOMAIN
# Remove special characters and convert to lowercase
DOMAIN=$(echo "$DOMAIN" | tr -cd '[:alnum:].-' | tr '[:upper:]' '[:lower:]')

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain name cannot be empty!${NORMAL}"
    exit 1
fi

# Validate domain name format
if ! echo "$DOMAIN" | grep -qP '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$'; then
    echo -e "${RED}Invalid domain name format! Only letters, numbers, hyphens and dots are allowed.${NORMAL}"
    echo -e "${RED}Domain cannot start or end with hyphen.${NORMAL}"
    exit 1
fi

echo -e "${BLUE}Using domain name: ${GREEN}$DOMAIN${NORMAL}"

# Create project directory
echo -e "${BLUE}Creating project directory...${NORMAL}"
sudo mkdir -p "/var/www/$DOMAIN/public"
sudo chown -R $USER:www-data "/var/www/$DOMAIN"
sudo chmod -R 775 "/var/www/$DOMAIN"
sudo chmod g+s "/var/www/$DOMAIN"
check_status "Project directory created and permissions set" || exit 1

# Create index.php
echo -e "${BLUE}Creating index.php...${NORMAL}"
sudo tee "/var/www/$DOMAIN/public/index.php" > /dev/null << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $DOMAIN</title>
    <style>
        body { 
            font-family: Arial, sans-serif;
            margin: 40px;
            text-align: center;
        }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Project $DOMAIN created successfully!</h1>
    <p>PHP Version: <?php echo PHP_VERSION; ?></p>
</body>
</html>
EOF
check_status "Index.php created" || exit 1

# Create Nginx configuration
echo -e "${BLUE}Creating Nginx configuration...${NORMAL}"
sudo tee "/etc/nginx/sites-available/$DOMAIN" > /dev/null << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;
    root /var/www/$DOMAIN/public;

    # SSL Configuration
    ssl_certificate     /etc/ssl/certs/$DOMAIN.crt;
    ssl_certificate_key /etc/ssl/private/$DOMAIN.key;
    
    # Strong SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    
    # SSL Session Configuration
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_buffer_size 4k;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Permissions-Policy "interest-cohort=()" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Other security measures
    server_tokens off;
    client_max_body_size 64M;
    
    index index.php index.html;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
check_status "Nginx configuration created" || exit 1

# Create symbolic link
echo -e "${BLUE}Creating symbolic link...${NORMAL}"
sudo ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/"
check_status "Symbolic link created" || exit 1

# Update hosts file
echo -e "${BLUE}Updating hosts file...${NORMAL}"
if ! grep -q "127.0.0.1.*$DOMAIN" /etc/hosts; then
    echo "127.0.0.1       $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
    check_status "Hosts file updated" || exit 1
fi

# Replace SSL certificate check and installation
echo -e "${BLUE}Checking SSL certificates...${NORMAL}"
if [ ! -f "/etc/ssl/certs/$DOMAIN.crt" ] || [ ! -f "/etc/ssl/private/$DOMAIN.key" ]; then
    echo -e "${ORANGE}SSL certificates not found. Creating new self-signed certificates...${NORMAL}"
    
    # Create directories if they don't exist
    sudo mkdir -p /etc/ssl/certs
    sudo mkdir -p /etc/ssl/private
    
    # Generate private key and CSR
    sudo openssl req -x509 -newkey rsa:4096 \
        -keyout "/etc/ssl/private/$DOMAIN.key" \
        -out "/etc/ssl/certs/$DOMAIN.crt" \
        -days 365 -nodes \
        -subj "/C=VN/ST=Hanoi/L=Hoan Kiem/O=MyCompany/OU=IT Department/CN=$DOMAIN/emailAddress=huongchaytool5@gmail.com" \
        -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN"
    
    check_status "SSL certificates generated" || exit 1
    
    # Update permissions
    sudo chmod 644 "/etc/ssl/certs/$DOMAIN.crt"
    sudo chmod 600 "/etc/ssl/private/$DOMAIN.key"
    
    # Add to trusted certificates
    sudo cp "/etc/ssl/certs/$DOMAIN.crt" "/usr/local/share/ca-certificates/$DOMAIN.crt"
    sudo update-ca-certificates
    check_status "Certificate added to trusted store" || exit 1
fi

# Test and restart Nginx
echo -e "${BLUE}Testing Nginx configuration...${NORMAL}"
sudo nginx -t && sudo service nginx restart
check_status "Nginx restarted" || exit 1

echo -e "\n${GREEN}Virtual host created successfully!${NORMAL}"
echo -e "${ORANGE}Site available at: https://$DOMAIN${NORMAL}"
echo -e "${ORANGE}Project folder: /var/www/$DOMAIN${NORMAL}"

# After creating SSL certificates
echo -e "\n${ORANGE}Important Security Notice:${NORMAL}"
echo -e "This site is using a self-signed SSL certificate for development purposes."
echo -e "For production use, please install a proper SSL certificate from a trusted Certificate Authority."
echo -e "You can use Let's Encrypt to get a free trusted SSL certificate.\n"

echo -e "${BLUE}To trust this certificate on your local machine:${NORMAL}"
echo -e "1. Firefox: Go to Preferences -> Privacy & Security -> View Certificates -> Import"
echo -e "2. Chrome: Go to Settings -> Privacy and security -> Security -> Manage certificates -> Import"
echo -e "3. System-wide: Copy the certificate to your system's trust store:"
echo -e "   ${GREEN}sudo cp /etc/ssl/certs/nginx.crt /usr/local/share/ca-certificates/${DOMAIN}.crt"
echo -e "   sudo update-ca-certificates${NORMAL}\n"