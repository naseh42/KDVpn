#!/bin/bash

# تعریف رنگ‌ها برای نمایش پیام
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
apt install -y python3 python3-pip git curl wget unzip tar nginx mysql-server

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

# نصب کتابخانه‌های پایتون
echo -e "${GREEN}نصب کتابخانه‌های پایتون...${NC}"
pip3 install -r requirements.txt

# دانلود و نصب Sing-box
echo -e "${GREEN}دانلود و نصب Sing-box...${NC}"
curl -L -o sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz
tar -xzf sing-box.tar.gz -C /usr/local/bin/
rm sing-box.tar.gz

# دانلود و نصب XRay
echo -e "${GREEN}دانلود و نصب XRay...${NC}"
curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip xray.zip -d /usr/local/bin/
rm xray.zip

# انتقال فایل‌های پروژه
echo -e "${GREEN}انتقال فایل‌های پروژه...${NC}"
mv app.py /var/www/KDVpn/backend/
mv database.py /var/www/KDVpn/backend/
mv models.py /var/www/KDVpn/backend/
mv schemas.py /var/www/KDVpn/backend/
mv routers/* /var/www/KDVpn/backend/routers/
mv templates/* /var/www/KDVpn/backend/templates/
mv static/css/* /var/www/KDVpn/backend/static/css/

# تنظیمات Nginx
echo -e "${GREEN}تنظیم Nginx...${NC}"
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
nginx -t && systemctl restart nginx

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
