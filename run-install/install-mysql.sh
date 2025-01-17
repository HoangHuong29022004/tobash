#!/bin/bash

# Colors for output
NORMAL="\\033[0;39m"
GREEN="\\033[1;32m"
RED="\\033[1;31m"
BLUE="\\033[1;34m"
ORANGE="\\033[1;33m"

echo -e "${BLUE}=== MySQL Server Installation Script ===${NORMAL}"

# Check if MySQL is already installed
if command -v mysql &> /dev/null; then
    echo -e "${GREEN}MySQL is already installed!${NORMAL}"
    echo -e "${BLUE}MySQL version: ${NORMAL}$(mysql --version)"
    exit 0
fi

# Update package list
echo -e "${GREEN}Updating package list...${NORMAL}"
sudo apt update

# Install MySQL Server
echo -e "${GREEN}Installing MySQL Server...${NORMAL}"
sudo apt install -y mysql-server

# Check if installation was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}MySQL installation failed!${NORMAL}"
    exit 1
fi

# Start MySQL service
echo -e "${GREEN}Starting MySQL service...${NORMAL}"
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL installation
echo -e "${ORANGE}Running MySQL secure installation...${NORMAL}"
echo -e "${BLUE}Please follow the prompts to secure your MySQL installation:${NORMAL}"
sudo mysql_secure_installation

# Display MySQL status
echo -e "${BLUE}MySQL service status:${NORMAL}"
sudo systemctl status mysql --no-pager

# Print helpful information
echo -e "\n${BLUE}=== MySQL Installation Complete ===${NORMAL}"
echo -e "${GREEN}MySQL has been installed and secured!${NORMAL}"
echo -e "\n${ORANGE}Useful commands:${NORMAL}"
echo -e "- Start MySQL:    ${GREEN}sudo systemctl start mysql${NORMAL}"
echo -e "- Stop MySQL:     ${GREEN}sudo systemctl stop mysql${NORMAL}"
echo -e "- Restart MySQL:  ${GREEN}sudo systemctl restart mysql${NORMAL}"
echo -e "- Check status:   ${GREEN}sudo systemctl status mysql${NORMAL}"
echo -e "- Connect to MySQL: ${GREEN}sudo mysql -u root -p${NORMAL}"

# Create a test database and user (optional)
echo -e "\n${ORANGE}Would you like to create a test database and user? (y/n)${NORMAL}"
read -r create_test_db

if [ "$create_test_db" = "y" ]; then
    echo -e "${GREEN}Enter a name for the test database:${NORMAL}"
    read -r db_name
    echo -e "${GREEN}Enter a username for the test user:${NORMAL}"
    read -r db_user
    echo -e "${GREEN}Enter a password for the test user:${NORMAL}"
    read -r db_pass

    # Create database and user
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${db_name};"
    sudo mysql -e "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"

    echo -e "${GREEN}Test database and user created successfully!${NORMAL}"
    echo -e "${BLUE}Database name: ${NORMAL}${db_name}"
    echo -e "${BLUE}Username: ${NORMAL}${db_user}"
    echo -e "${BLUE}Password: ${NORMAL}${db_pass}"
fi

echo -e "\n${GREEN}MySQL installation and setup completed successfully!${NORMAL}" 