#!/bin/bash

# Cấp quyền thực thi cho script
chmod +x "$(dirname "$0")"/*.sh

# Kiểm tra xem sshpass có được cài đặt không
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}Lỗi: sshpass chưa được cài đặt. Vui lòng cài đặt sshpass để tiếp tục.${NORMAL}"
    exit 1
fi

# Màu sắc cho đầu ra
NORMAL="\\033[0;39m"
GREEN="\\033[1;32m"
RED="\\033[1;31m"
BLUE="\\033[1;34m"
ORANGE="\\033[1;33m"

# Tự động liệt kê các file trong thư mục connect
CONNECTIONS=()
for file in connect/*.sh; do
    CONNECTIONS+=("$(basename "$file")")
done

# Hàm hiển thị menu kết nối
show_connections() {
    echo -e "${BLUE}=== Chọn kết nối SSH ===${NORMAL}"
    for i in "${!CONNECTIONS[@]}"; do
        echo -e "${GREEN}[$i]${NORMAL} ${CONNECTIONS[$i]}"
    done
    echo -e "${ORANGE}[b] Quay lại${NORMAL}"
}

# Vòng lặp chính
while true; do
    show_connections
    read -p "Vui lòng nhập lựa chọn của bạn: " REPLY

    if [ "$REPLY" = "b" ]; then
        exit 0
    elif [[ $REPLY =~ ^[0-9]+$ ]] && [ $REPLY -ge 0 ] && [ $REPLY -lt ${#CONNECTIONS[@]} ]; then
        echo -e "${ORANGE}---> Đang kết nối tới: ${CONNECTIONS[$REPLY]}...${NORMAL}"
        exec bash "connect/${CONNECTIONS[$REPLY]}"
    else
        echo -e "${RED}Lựa chọn không hợp lệ. Vui lòng nhập một số hợp lệ hoặc 'b' để quay lại.${NORMAL}"
    fi
    echo -e "${BLUE}Nhấn Enter để tiếp tục...${NORMAL}"
    read
done
