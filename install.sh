#!/bin/bash

# مراحل نصب و پیکربندی XRay و Sing-box
echo "شروع نصب XRay و Sing-box ..."

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# دانلود و نصب XRay
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip -d /usr/local/xray/
chmod +x /usr/local/xray/xray

# دانلود و نصب Sing-box
echo "بررسی وجود Sing-box ..."
if [ ! -d "/usr/local/sing-box" ]; then
    wget https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz
    tar -zxvf sing-box-linux-amd64.tar.gz -C /usr/local/
    chmod +x /usr/local/sing-box
else
    echo "Sing-box قبلاً نصب شده است."
fi

# بررسی و ساخت پوشه‌های مورد نیاز
echo "بررسی پوشه‌ها و ساخت پوشه‌های لازم ..."
mkdir -p /path/to/KDVpn/backend/templates
mkdir -p /path/to/KDVpn/backend/static/css

# انتقال فایل‌های HTML به دایرکتوری templates
echo "انتقال فایل‌های HTML به پوشه templates ..."
mv /path/to/downloaded/dashboard.html /path/to/KDVpn/backend/templates/
mv /path/to/downloaded/users.html /path/to/KDVpn/backend/templates/
mv /path/to/downloaded/domains.html /path/to/KDVpn/backend/templates/
mv /path/to/downloaded/settings.html /path/to/KDVpn/backend/templates/

# انتقال فایل‌های Python به دایرکتوری backend
echo "انتقال فایل‌های Python به پوشه backend ..."
mv /path/to/downloaded/main.py /path/to/KDVpn/backend/

# انتقال فایل‌های CSS به دایرکتوری static/css
echo "انتقال فایل‌های CSS به پوشه static/css ..."
mv /path/to/downloaded/styles.css /path/to/KDVpn/backend/static/css/

# ایجاد سرویس‌ها برای XRay و Sing-box
echo "[Unit]
Description=XRay service
After=network.target

[Service]
ExecStart=/usr/local/xray/xray run
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/xray.service

echo "[Unit]
Description=Sing-box service
After=network.target

[Service]
ExecStart=/usr/local/sing-box run
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
      'vnext': [{
        'address': 'example.com',
        'port': 443,
        'users': [{
          'id': 'uuid-generated-here',
          'alterId': 64
        }]
      }]
    }
  }]
}" > /etc/sing-box/config.json

# نمایش پیغام نهایی
echo "تمامی فایل‌ها به دایرکتوری‌های مناسب منتقل شدند و نصب به اتمام رسید!"
