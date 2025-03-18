#!/bin/bash

# ایجاد پسورد تصادفی برای MySQL
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
MYSQL_USER_PASSWORD=$(openssl rand -base64 12)

# ذخیره پسورد MySQL در فایل کانفیگ
echo "[client]" > ~/.my.cnf
echo "user=root" >> ~/.my.cnf
echo "password=${MYSQL_ROOT_PASSWORD}" >> ~/.my.cnf
chmod 600 ~/.my.cnf  # تغییر دسترسی برای امنیت بیشتر

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# دانلود و نصب XRay
XRayVersion="v1.5.0"
XRayDownloadUrl="https://github.com/XTLS/Xray-core/releases/download/${XRayVersion}/Xray-linux-amd64-${XRayVersion}.tar.gz"
wget $XRayDownloadUrl -O /tmp/XRay-linux.tar.gz
tar -zxvf /tmp/XRay-linux.tar.gz -C /usr/local/bin/
chmod +x /usr/local/bin/xray

# دانلود و نصب Sing-box
SingBoxVersion="v1.11.5"
SingBoxDownloadUrl="https://github.com/SagerNet/sing-box/releases/download/${SingBoxVersion}/sing-box-linux-amd64.tar.gz"
wget $SingBoxDownloadUrl -O /tmp/sing-box-linux.tar.gz
tar -zxvf /tmp/sing-box-linux.tar.gz -C /usr/local/bin/
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

# پیکربندی MySQL
echo "شروع پیکربندی MySQL ..."

# درخواست پسورد MySQL
echo "ایجاد پایگاه‌داده و کاربر جدید در MySQL ..."
mysql -e "CREATE DATABASE IF NOT EXISTS kurdan;"
mysql -e "CREATE USER IF NOT EXISTS 'kurdan_user'@'localhost' IDENTIFIED BY '${MYSQL_USER_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# ایجاد پوشه‌های لازم
echo "بررسی پوشه‌ها و ساخت پوشه‌های لازم ..."
mkdir -p /root/KDVpn/backend/templates
mkdir -p /root/KDVpn/backend/static/css
mkdir -p /root/KDVpn/backend/static/js

# انتقال فایل‌های HTML به پوشه templates
echo "انتقال فایل‌های HTML به پوشه templates ..."
mv /root/KDVpn/dashboard.html /root/KDVpn/backend/templates/dashboard.html
mv /root/KDVpn/users.html /root/KDVpn/backend/templates/users.html
mv /root/KDVpn/domains.html /root/KDVpn/backend/templates/domains.html
mv /root/KDVpn/settings.html /root/KDVpn/backend/templates/settings.html

# انتقال فایل‌های Python به پوشه backend
echo "انتقال فایل‌های Python به پوشه backend ..."
mv /root/KDVpn/main.py /root/KDVpn/backend/main.py

# انتقال فایل‌های CSS به پوشه static/css
echo "انتقال فایل‌های CSS به پوشه static/css ..."
mv /root/KDVpn/styles.css /root/KDVpn/backend/static/css/styles.css

# شروع پیکربندی XRay و Sing-box
echo "Setting up XRay and Sing-box configs ..."
mkdir -p /etc/xray
mkdir -p /etc/sing-box

# تنظیمات اولیه برای XRay و Sing-box
echo "{
  \"inbounds\": [{
    \"port\": 10086,
    \"protocol\": \"vmess\",
    \"settings\": {
      \"clients\": [{
        \"id\": \"uuid-generated-here\",
        \"alterId\": 64
      }]
    }
  },
  {
    \"port\": 10087,
    \"protocol\": \"hysteria\",
    \"settings\": {
      \"clients\": [{
        \"id\": \"uuid-generated-here\",
        \"alterId\": 64
      }]
    }
  }]
}" > /etc/xray/config.json

# اضافه کردن فایل کانفیگ Sing-box
echo "{
  \"log\": {
    \"level\": \"info\",
    \"output\": \"stdout\"
  },
  \"outbounds\": [{
    \"protocol\": \"vmess\",
    \"settings\": {
      \"vnext\": [{
        \"address\": \"example.com\",
        \"port\": 443,
        \"users\": [{
          \"id\": \"uuid-generated-here\",
          \"alterId\": 64
        }]
      }]
    }
  }]
}" > /etc/sing-box/config.json

echo "تمامی مراحل با موفقیت به پایان رسید!"
