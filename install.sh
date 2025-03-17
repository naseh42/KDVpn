#!/bin/bash

# مراحل نصب و پیکربندی XRay و Sing-box
echo "شروع نصب XRay و Sing-box ..."

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git npm

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# دانلود و نصب XRay
wget https://github.com/XTLS/Xray-core/releases/download/v1.5.0/Xray-linux-amd64-1.5.0.tar.gz
tar -zxvf Xray-linux-amd64-1.5.0.tar.gz
mv xray /usr/local/bin/
chmod +x /usr/local/bin/xray

# دانلود و نصب Sing-box
wget https://github.com/SagerNet/sing-box/releases/download/v1.0.0/sing-box-linux-amd64.tar.gz
tar -zxvf sing-box-linux-amd64.tar.gz
mv sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box

# ایجاد سرویس‌ها برای XRay و Sing-box
echo "[Unit]
Description=XRay service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/xray.service

echo "[Unit]
Description=Sing-box service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/sing-box.service

# فعال‌سازی و شروع سرویس‌ها
systemctl enable xray
systemctl enable sing-box
systemctl start xray
systemctl start sing-box

# پیکربندی پایگاه‌داده MySQL
echo "شروع پیکربندی MySQL ..."

# درخواست پسورد MySQL
read -sp "Enter MySQL root password: " mysql_root_password
mysql -e "CREATE DATABASE kurdan;"
mysql -e "CREATE USER 'kurdan_user'@'localhost' IDENTIFIED BY '${mysql_root_password}';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# پیکربندی XRay و Sing-box
mkdir -p /etc/xray
mkdir -p /etc/sing-box

# تنظیمات اولیه برای XRay و Sing-box
echo "Setting up XRay and Sing-box configs ..."

# اضافه کردن فایل کانفیگ XRay
echo "{
  'inbounds': [{
    'port': 10086,
    'protocol': 'vmess',
    'settings': {
      'clients': [{
        'id': 'uuid-generated-here',
        'alterId': 64
      }]
    }
  },
  {
    'port': 10087,
    'protocol': 'hysteria',
    'settings': {
      'clients': [{
        'id': 'uuid-generated-here',
        'alterId': 64
      }]
    }
  }]
}" > /etc/xray/config.json

# اضافه کردن فایل کانفیگ Sing-box
echo "{
  'log': {
    'level': 'info',
    'output': 'stdout'
  },
  'outbounds': [{
    'protocol': 'vmess',
    'settings': {
      'vnext': [{
        'address': 'example.com',
        'port': 443,
        'users': [{
          'id': 'uuid-generated-here',
          'alterId': 64
        }]
      }]
    }
  },
  {
    'protocol': 'xtcp',
    'settings': {
...
" > /etc/sing-box/config.json

# --- اضافه کردن مراحل نصب پنل Kurdan ---

# مسیر نصب پروژه را تنظیم کنیم
INSTALL_DIR="/var/www/html/kurdan"

# اگر دایرکتوری مقصد قبلاً وجود داشته باشد، حذف کنیم
if [ -d "$INSTALL_DIR" ]; then
    echo "دایرکتوری قبلاً وجود دارد. حذف آن ..."
    rm -rf "$INSTALL_DIR"
fi

# کلون کردن مخزن از گیت‌هاب به مسیر نصب
echo "کلون کردن مخزن از گیت‌هاب ..."
git clone https://github.com/naseh42/KDVpn.git "$INSTALL_DIR"

# وارد دایرکتوری پروژه شده و نصب npm
cd "$INSTALL_DIR" || exit
echo "نصب وابستگی‌های npm ..."
npm install

# اطمینان حاصل کنیم که فایل `package.json` در دایرکتوری پروژه موجود باشد
if [ ! -f "package.json" ]; then
    echo "فایل package.json پیدا نشد! ایجاد فایل package.json ..."
    echo '{
        "name": "kurdan",
        "version": "1.0.0",
        "main": "index.js",
        "dependencies": {
            "express": "^4.17.1",
            "npm": "^7.20.3"
        }
    }' > package.json
    npm install
fi

# شروع پیکربندی nginx
echo "پیکربندی Nginx ..."
# این بخش به پیکربندی و ایجاد فایل کانفیگ Nginx شما مربوط می‌شود

echo "نصب و پیکربندی تمام شد!"
