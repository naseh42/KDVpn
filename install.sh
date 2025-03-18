#!/bin/bash

# تعریف رنگ‌ها برای پیام‌ها
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}شروع نصب و پیکربندی...${NC}"

# بررسی دسترسی
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}لطفاً اسکریپت را با دسترسی ریشه (sudo) اجرا کنید.${NC}"
    exit
fi

# به‌روزرسانی مخازن
echo -e "${GREEN}به‌روزرسانی مخازن...${NC}"
apt update && apt upgrade -y

# نصب ابزارهای ضروری
echo -e "${GREEN}نصب ابزارهای ضروری...${NC}"
apt install -y python3 python3-pip python3.10-venv git curl wget unzip tar nginx mysql-server

# تنظیم و راه‌اندازی MySQL
echo -e "${GREEN}نصب و تنظیم MySQL...${NC}"
service mysql start
mysql -e "CREATE DATABASE IF NOT EXISTS kdvpndb;"
mysql -e "CREATE USER IF NOT EXISTS 'kdvpnuser'@'localhost' IDENTIFIED BY 'password';"
mysql -e "GRANT ALL PRIVILEGES ON kdvpndb.* TO 'kdvpnuser'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
cat <<EOL > /etc/mysql/conf.d/kdvpn.cnf
[mysqld]
bind-address = 127.0.0.1
EOL
service mysql restart

# ایجاد پوشه‌های پروژه
echo -e "${GREEN}ایجاد پوشه‌های پروژه...${NC}"
mkdir -p /var/www/KDVpn/backend/templates
mkdir -p /var/www/KDVpn/backend/static/css
mkdir -p /var/www/KDVpn/backend/routers

# تولید فایل requirements.txt
echo -e "${GREEN}ایجاد فایل requirements.txt...${NC}"
cat <<EOL > requirements.txt
fastapi
sqlalchemy
mysql-connector-python
jinja2
python-decouple
EOL

# تنظیم محیط مجازی pip
echo -e "${GREEN}ایجاد محیط مجازی برای pip...${NC}"
python3 -m venv env
source env/bin/activate

# نصب کتابخانه‌های پایتون
echo -e "${GREEN}نصب کتابخانه‌های پایتون...${NC}"
pip install -r requirements.txt

# انتقال فایل‌ها بر اساس جستجوی نام فایل‌ها
echo -e "${GREEN}پیدا کردن و انتقال فایل‌های پروژه...${NC}"

move_file() {
    FILE_NAME=$1
    DEST_DIR=$2
    FILE_PATH=$(find . -type f -name "$FILE_NAME" 2>/dev/null | head -n 1)
    
    if [ -n "$FILE_PATH" ]; then
        mv "$FILE_PATH" "$DEST_DIR"
        echo -e "${GREEN}$FILE_NAME انتقال یافت به $DEST_DIR${NC}"
    else
        echo -e "${RED}$FILE_NAME یافت نشد.${NC}"
    fi
}

move_file "app.py" "/var/www/KDVpn/backend/"
move_file "database.py" "/var/www/KDVpn/backend/"
move_file "models.py" "/var/www/KDVpn/backend/"
move_file "schemas.py" "/var/www/KDVpn/backend/"
move_file "routers/*" "/var/www/KDVpn/backend/routers/"
move_file "templates/*" "/var/www/KDVpn/backend/templates/"
move_file "css/*" "/var/www/KDVpn/backend/static/css/"

# تنظیم Nginx
echo -e "${GREEN}تنظیم Nginx...${NC}"
if [ -L "/etc/nginx/sites-enabled/KDVpn" ]; then
    echo -e "${RED}لینک نمادین قبلی یافت شد. حذف می‌شود...${NC}"
    rm -f /etc/nginx/sites-enabled/KDVpn
fi

cat <<EOL > /etc/nginx/sites-available/KDVpn
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /static/ {
        alias /var/www/KDVpn/backend/static/;
    }
}
EOL
ln -s /etc/nginx/sites-available/KDVpn /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# راه‌اندازی اپلیکیشن
echo -e "${GREEN}راه‌اندازی اپلیکیشن...${NC}"
cat <<EOL > /etc/systemd/system/kdvpnd.service
[Unit]
Description=KDVpn FastAPI Application
After=network.target

[Service]
User=root
WorkingDirectory=/var/www/KDVpn/backend
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable kdvpnd
systemctl start kdvpnd

echo -e "${GREEN}نصب و راه‌اندازی با موفقیت انجام شد!${NC}"
