#!/bin/bash

# Colors for output
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

echo -e "${BLUE}=== Windows SSL Certificate Installation ===${NORMAL}"

# Check if running in WSL
if ! grep -qi microsoft /proc/version; then
    echo -e "${RED}This script must be run in Windows Subsystem for Linux (WSL)${NORMAL}"
    exit 1
fi

# Function to create and install certificate
create_and_install_cert() {
    local DOMAIN=$1
    echo -e "\n${BLUE}Creating and installing certificate for: $DOMAIN${NORMAL}"

    # Create directories if they don't exist
    sudo mkdir -p /etc/ssl/certs
    sudo mkdir -p /etc/ssl/private

    # Generate private key and certificate
    sudo openssl req -x509 -newkey rsa:4096 \
        -keyout "/etc/ssl/private/$DOMAIN.key" \
        -out "/etc/ssl/certs/$DOMAIN.crt" \
        -days 3650 -nodes \
        -subj "/C=VN/ST=Hanoi/L=Hoan Kiem/O=Local Development/OU=Development/CN=$DOMAIN" \
        -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN"
    check_status "Certificate generated" || return 1

    # Set permissions
    sudo chmod 644 "/etc/ssl/certs/$DOMAIN.crt"
    sudo chmod 600 "/etc/ssl/private/$DOMAIN.key"

    # Copy to Windows temp
    WINDOWS_TEMP="/mnt/c/Windows/Temp"
    sudo cp "/etc/ssl/certs/$DOMAIN.crt" "$WINDOWS_TEMP/$DOMAIN.crt"
    check_status "Certificate copied to Windows" || return 1

    # Create PowerShell script for import
    cat >"$WINDOWS_TEMP/import-$DOMAIN-cert.ps1" <<EOF
# Remove existing certificate if exists
Get-ChildItem -Path Cert:\\LocalMachine\\Root | 
    Where-Object {$_.Subject -like "*CN=$DOMAIN*"} | 
    Remove-Item

# Import new certificate
\$cert = Import-Certificate -FilePath "C:\\Windows\\Temp\\$DOMAIN.crt" -CertStoreLocation Cert:\\LocalMachine\\Root
if(\$?) {
    Write-Host "Certificate for $DOMAIN imported successfully"
    Remove-Item "C:\\Windows\\Temp\\$DOMAIN.crt"
    Remove-Item "C:\\Windows\\Temp\\import-$DOMAIN-cert.ps1"
}
EOF
    check_status "Import script created"

    echo -e "${GREEN}To install certificate for $DOMAIN, run these commands in PowerShell as Administrator:${NORMAL}"
    echo -e "   ${ORANGE}cd C:\\Windows\\Temp${NORMAL}"
    echo -e "   ${ORANGE}Set-ExecutionPolicy Bypass -Scope Process -Force${NORMAL}"
    echo -e "   ${ORANGE}.\\import-$DOMAIN-cert.ps1${NORMAL}"
}

# Get list of domains from Nginx sites-available
echo -e "${BLUE}Available domains from Nginx configuration:${NORMAL}"
NGINX_SITES="/etc/nginx/sites-available"
INDEX=0
declare -a DOMAINS_ARRAY

for SITE in $(ls $NGINX_SITES | grep -v default); do
    if [ -f "$NGINX_SITES/$SITE" ]; then
        DOMAINS_ARRAY[$INDEX]="$SITE"
        echo -e "${GREEN}[$INDEX]${NORMAL} $SITE"
        ((INDEX++))
    fi
done

if [ $INDEX -eq 0 ]; then
    echo -e "${ORANGE}No domains found in Nginx configuration${NORMAL}"
    exit 1
fi

echo -e "${ORANGE}[a]${NORMAL} Install certificates for all domains"
echo -e "${RED}[q]${NORMAL} Quit"

# Get user choice
read -p "Enter your choice: " CHOICE

case $CHOICE in
"q")
    echo -e "${BLUE}Exiting...${NORMAL}"
    exit 0
    ;;
"a")
    echo -e "${ORANGE}Installing certificates for all domains...${NORMAL}"
    for DOMAIN in "${DOMAINS_ARRAY[@]}"; do
        create_and_install_cert "$DOMAIN"
    done
    ;;
*)
    if [[ $CHOICE =~ ^[0-9]+$ ]] && [ "$CHOICE" -lt "$INDEX" ]; then
        create_and_install_cert "${DOMAINS_ARRAY[$CHOICE]}"
    else
        echo -e "${RED}Invalid choice!${NORMAL}"
        exit 1
    fi
    ;;
esac

echo -e "\n${BLUE}Additional steps:${NORMAL}"
echo -e "1. Run the PowerShell commands shown above as Administrator"
echo -e "2. Clear your browser cache and restart browsers"
echo -e "3. If using Chrome/Edge, you may need to:"
echo -e "   - Visit chrome://net-internals/#hsts"
echo -e "   - Click 'Delete domain security policies'"
echo -e "   - Enter your domain and click 'Delete'"
echo -e "\n${ORANGE}Note: Certificates will be valid for 10 years${NORMAL}"
