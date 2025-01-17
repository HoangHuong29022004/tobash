#!/bin/bash

# Colors for output
NORMAL="\\033[0;39m"
GREEN="\\033[1;32m"
RED="\\033[1;31m"
BLUE="\\033[1;34m"
ORANGE="\\033[1;33m"

echo -e "${BLUE}=== Yarn Package Manager Installation Script ===${NORMAL}"

# Check if Yarn is already installed
if command -v yarn &> /dev/null; then
    echo -e "${GREEN}Yarn is already installed!${NORMAL}"
    echo -e "${BLUE}Current Yarn version: ${NORMAL}$(yarn --version)"
    exit 0
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${ORANGE}Node.js is required but not installed.${NORMAL}"
    echo -e "${GREEN}Installing Node.js first...${NORMAL}"
    
    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    
    # Install Node.js
    sudo apt-get install -y nodejs
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install Node.js. Please install it manually.${NORMAL}"
        exit 1
    fi
fi

# Import the Yarn GPG key
echo -e "${GREEN}Adding Yarn repository...${NORMAL}"
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -

# Add Yarn repository
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

# Update package list
echo -e "${GREEN}Updating package list...${NORMAL}"
sudo apt update

# Install Yarn
echo -e "${GREEN}Installing Yarn...${NORMAL}"
sudo apt install -y yarn

# Verify installation
if command -v yarn &> /dev/null; then
    echo -e "${GREEN}Yarn installed successfully!${NORMAL}"
    echo -e "${BLUE}Yarn version: ${NORMAL}$(yarn --version)"
    echo -e "${BLUE}Node.js version: ${NORMAL}$(node --version)"
    echo -e "${BLUE}npm version: ${NORMAL}$(npm --version)"
    
    # Print helpful information
    echo -e "\n${ORANGE}Useful Yarn commands:${NORMAL}"
    echo -e "- Initialize a new project: ${GREEN}yarn init${NORMAL}"
    echo -e "- Add a package: ${GREEN}yarn add [package-name]${NORMAL}"
    echo -e "- Install all dependencies: ${GREEN}yarn install${NORMAL}"
    echo -e "- Run a script: ${GREEN}yarn run [script-name]${NORMAL}"
    echo -e "- Upgrade Yarn: ${GREEN}yarn set version latest${NORMAL}"
else
    echo -e "${RED}Yarn installation failed.${NORMAL}"
    exit 1
fi 