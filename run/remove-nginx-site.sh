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

echo -e "${BLUE}=== Remove Nginx Virtual Host ===${NORMAL}"

# Get list of available sites
SITES_AVAILABLE=$(ls /etc/nginx/sites-available/ | grep -v default)

if [ -z "$SITES_AVAILABLE" ]; then
    echo -e "${ORANGE}No custom virtual hosts found.${NORMAL}"
    exit 0
fi

# Display available sites
echo -e "${BLUE}Available virtual hosts:${NORMAL}"
INDEX=0
declare -a SITES_ARRAY

for SITE in $SITES_AVAILABLE; do
    SITES_ARRAY[$INDEX]=$SITE
    echo -e "${GREEN}[$INDEX]${NORMAL} $SITE"
    ((INDEX++))
done

echo -e "${ORANGE}[a]${NORMAL} Remove all sites"
echo -e "${RED}[q]${NORMAL} Quit"

# Get user choice
while true; do
    read -p "Enter your choice: " CHOICE
    
    if [ "$CHOICE" = "q" ]; then
        echo -e "${BLUE}Exiting...${NORMAL}"
        exit 0
    elif [ "$CHOICE" = "a" ]; then
        echo -e "${RED}WARNING: This will remove all custom virtual hosts!${NORMAL}"
        read -p "Are you sure? (y/n): " CONFIRM
        if [ "$CONFIRM" = "y" ]; then
            for SITE in "${SITES_ARRAY[@]}"; do
                echo -e "${BLUE}Removing $SITE...${NORMAL}"
                
                # Remove from sites-enabled
                sudo rm -f "/etc/nginx/sites-enabled/$SITE"
                check_status "Removed from sites-enabled" || continue
                
                # Remove from sites-available
                sudo rm -f "/etc/nginx/sites-available/$SITE"
                check_status "Removed from sites-available" || continue
                
                # Remove from hosts file
                sudo sed -i "/.* $SITE/d" /etc/hosts
                check_status "Removed from hosts file" || continue
                
                # Remove SSL certificates if they exist and are not used by other sites
                if [ -f "/etc/ssl/certs/$SITE.crt" ]; then
                    sudo rm -f "/etc/ssl/certs/$SITE.crt"
                    sudo rm -f "/etc/ssl/private/$SITE.key"
                    check_status "Removed SSL certificates" || continue
                fi
                
                # Remove project directory
                echo -e "${ORANGE}Do you want to remove the project directory /var/www/$SITE? (y/n)${NORMAL}"
                read -p "Choice: " REMOVE_DIR
                if [ "$REMOVE_DIR" = "y" ]; then
                    sudo rm -rf "/var/www/$SITE"
                    check_status "Removed project directory"
                fi
            done
        fi
        break
    elif [[ $CHOICE =~ ^[0-9]+$ ]] && [ "$CHOICE" -lt "$INDEX" ]; then
        SITE=${SITES_ARRAY[$CHOICE]}
        echo -e "${BLUE}Removing $SITE...${NORMAL}"
        
        # Remove from sites-enabled
        sudo rm -f "/etc/nginx/sites-enabled/$SITE"
        check_status "Removed from sites-enabled" || continue
        
        # Remove from sites-available
        sudo rm -f "/etc/nginx/sites-available/$SITE"
        check_status "Removed from sites-available" || continue
        
        # Remove from hosts file
        sudo sed -i "/.* $SITE/d" /etc/hosts
        check_status "Removed from hosts file" || continue
        
        # Remove SSL certificates if they exist and are not used by other sites
        if [ -f "/etc/ssl/certs/$SITE.crt" ]; then
            sudo rm -f "/etc/ssl/certs/$SITE.crt"
            sudo rm -f "/etc/ssl/private/$SITE.key"
            check_status "Removed SSL certificates" || continue
        fi
        
        # Remove project directory
        echo -e "${ORANGE}Do you want to remove the project directory /var/www/$SITE? (y/n)${NORMAL}"
        read -p "Choice: " REMOVE_DIR
        if [ "$REMOVE_DIR" = "y" ]; then
            sudo rm -rf "/var/www/$SITE"
            check_status "Removed project directory"
        fi
        break
    else
        echo -e "${RED}Invalid choice!${NORMAL}"
    fi
done

# Restart Nginx
echo -e "${BLUE}Restarting Nginx...${NORMAL}"
# Check if running in WSL
if grep -qi microsoft /proc/version; then
    # WSL environment
    sudo service nginx restart
else
    # Standard Linux environment
    sudo systemctl restart nginx
fi
check_status "Nginx restarted"

echo -e "\n${GREEN}Virtual host(s) removed successfully!${NORMAL}" 