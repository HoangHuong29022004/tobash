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

echo -e "${BLUE}=== Tạo Virtual Host ===${NORMAL}"

# Set default PHP version
DEFAULT_PHP="8.2"
PHP_VERSION=$DEFAULT_PHP

# Show available PHP versions and allow change
echo -e "${BLUE}Phiên bản PHP hiện có:${NORMAL}"
ls /usr/sbin/php-fpm* | grep -o 'php-fpm[0-9.]*' | sort
echo -e "${GREEN}Mặc định sử dụng PHP $DEFAULT_PHP${NORMAL}"
read -p "Bạn có muốn đổi phiên bản PHP không? (y/N): " change_php

if [ "$change_php" = "y" ] || [ "$change_php" = "Y" ]; then
    read -p "Nhập phiên bản PHP (vd: 8.3): " PHP_VERSION
fi

# Validate PHP version
if [ ! -f "/usr/sbin/php-fpm$PHP_VERSION" ]; then
    echo -e "${RED}Không tìm thấy PHP-FPM phiên bản $PHP_VERSION!${NORMAL}"
    exit 1
fi

# Get domain name and validate
read -p "Nhập tên miền (vd: project.code): " DOMAIN
# Remove special characters and convert to lowercase
DOMAIN=$(echo "$DOMAIN" | tr -cd '[:alnum:].-' | tr '[:upper:]' '[:lower:]')

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Tên miền không được để trống!${NORMAL}"
    exit 1
fi

# Validate domain name format
if ! echo "$DOMAIN" | grep -qP '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$'; then
    echo -e "${RED}Tên miền không hợp lệ! Chỉ được phép dùng chữ cái, số, dấu gạch ngang và dấu chấm.${NORMAL}"
    echo -e "${RED}Tên miền không được bắt đầu hoặc kết thúc bằng dấu gạch ngang.${NORMAL}"
    exit 1
fi

echo -e "${BLUE}Sử dụng tên miền: ${GREEN}$DOMAIN${NORMAL}"

# Create project directory
echo -e "${BLUE}Creating project directory...${NORMAL}"

# Kiểm tra và cài đặt gói acl nếu chưa có
if ! command -v setfacl &> /dev/null; then
    echo -e "${BLUE}Đang cài đặt gói acl...${NORMAL}"
    sudo apt-get update && sudo apt-get install -y acl
    check_status "Cài đặt gói acl" || exit 1
fi

sudo mkdir -p "/var/www/$DOMAIN/public"
sudo chown -R $USER:www-data "/var/www/$DOMAIN"
sudo chmod -R 775 "/var/www/$DOMAIN"
sudo chmod g+s "/var/www/$DOMAIN"
# Cấp full quyền cho thư mục
sudo setfacl -R -d -m u:$USER:rwx,g:www-data:rwx "/var/www/$DOMAIN"
sudo setfacl -R -m u:$USER:rwx,g:www-data:rwx "/var/www/$DOMAIN"
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
echo -e "${BLUE}Tạo cấu hình Nginx...${NORMAL}"
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
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    
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
check_status "Đã tạo cấu hình Nginx" || exit 1

# Tạo SSL certificate
echo -e "${BLUE}Tạo SSL certificate...${NORMAL}"
if [ ! -f "/etc/ssl/certs/$DOMAIN.crt" ] || [ ! -f "/etc/ssl/private/$DOMAIN.key" ]; then
    sudo mkdir -p /etc/ssl/certs
    sudo mkdir -p /etc/ssl/private
    
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "/etc/ssl/private/$DOMAIN.key" \
        -out "/etc/ssl/certs/$DOMAIN.crt" \
        -subj "/CN=$DOMAIN" \
        -addext "subjectAltName=DNS:$DOMAIN"
    
    check_status "Đã tạo SSL certificate" || exit 1
    
    sudo chmod 644 "/etc/ssl/certs/$DOMAIN.crt"
    sudo chmod 600 "/etc/ssl/private/$DOMAIN.key"
fi

# Create symbolic link
echo -e "${BLUE}Tạo symbolic link...${NORMAL}"
sudo ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/"
check_status "Đã tạo symbolic link" || exit 1

# Update Windows hosts file
echo -e "\n${BLUE}Đang cập nhật file hosts của Windows...${NORMAL}"
WINDOWS_TEMP="/mnt/c/Windows/Temp"
WINDOWS_HOSTS="/mnt/c/Windows/System32/drivers/etc/hosts"

if [ -f "$WINDOWS_HOSTS" ]; then
    # Create PowerShell script
    cat > "$WINDOWS_TEMP/update-hosts.ps1" << 'EOF'
# Run as Administrator
$ErrorActionPreference = "Stop"

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$entry = "127.0.0.1       DOMAIN_PLACEHOLDER"

# Ensure running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Requires Administrator privileges"
    exit 1
}

try {
    # Take ownership and grant full permissions
    $acl = Get-Acl $hostsFile
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity.Name, "FullControl", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl -Path $hostsFile -AclObject $acl

    # Read and update hosts file
    $content = Get-Content $hostsFile
    if (-not ($content -contains $entry)) {
        Add-Content -Path $hostsFile -Value $entry -Force
        Write-Host "Domain added successfully"
    } else {
        Write-Host "Domain already exists"
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    # Reset permissions
    icacls $hostsFile /reset
}
EOF

    # Replace placeholder with actual domain
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$WINDOWS_TEMP/update-hosts.ps1"

    echo -e "${BLUE}Đang thêm domain vào file hosts...${NORMAL}"
    
    # Execute PowerShell script
    powershell.exe -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\update-hosts.ps1' -Verb RunAs -Wait"

    # Verify update
    sleep 2
    if grep -q "127.0.0.1.*$DOMAIN" "$WINDOWS_HOSTS"; then
        echo -e "${GREEN}✓ Đã cập nhật file hosts thành công${NORMAL}"
    else
        echo -e "${ORANGE}Không thể tự động cập nhật. Vui lòng thêm thủ công dòng sau vào file:${NORMAL}"
        echo -e "${ORANGE}C:\\Windows\\System32\\drivers\\etc\\hosts${NORMAL}"
        echo -e "${GREEN}127.0.0.1       $DOMAIN${NORMAL}"
        
        # Create backup file
        echo "127.0.0.1       $DOMAIN" > "$WINDOWS_TEMP/host-entry.txt"
        echo -e "${BLUE}Đã lưu nội dung cần thêm vào: ${NORMAL}C:\\Windows\\Temp\\host-entry.txt"
    fi
fi

# Kiểm tra và khởi động lại Nginx
echo -e "${BLUE}Kiểm tra cấu hình Nginx...${NORMAL}"
sudo nginx -t && sudo service nginx restart
check_status "Đã khởi động lại Nginx" || exit 1

echo -e "\n${GREEN}=== Hoàn tất! ===${NORMAL}"
echo -e "Website: ${ORANGE}https://$DOMAIN${NORMAL}"
echo -e "Thư mục: ${ORANGE}/var/www/$DOMAIN${NORMAL}\n"