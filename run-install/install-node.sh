#!/bin/bash

# Màu sắc cho output
NORMAL="\033[0;39m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"

echo -e "${BLUE}=== Cài đặt Node.js ===${NORMAL}"

# Cập nhật package list
echo -e "${GREEN}Đang cập nhật package list...${NORMAL}"
sudo apt update

# Thêm NodeSource repository
echo -e "${GREEN}Đang thêm NodeSource repository...${NORMAL}"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

# Cài đặt Node.js
echo -e "${GREEN}Đang cài đặt Node.js...${NORMAL}"
sudo apt install -y nodejs

# Hiển thị phiên bản
echo -e "${BLUE}Phiên bản Node.js: ${NORMAL}$(node -v)"
echo -e "${BLUE}Phiên bản npm: ${NORMAL}$(npm -v)"
