#!/bin/bash

# مراحل نصب و پیکربندی XRay و Sing-box
echo "شروع نصب پیش‌نیازها ..."

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git tar zip 

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# دانلود و نصب XRay
wget -O xray.tar.gz https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
mkdir -p /usr/local/xray
tar -zxvf xray.tar.gz -C /usr/local/xray
chmod +x /usr/local/xray/xray

# دانلود و نصب Sing-box
wget -O sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz
mkdir -p /usr/local/sing-box
tar -zxvf sing-box.tar.gz -C /usr/local/sing-box
chmod +x /usr/local/sing-box/sing-box

# ایجاد دایرکتوری‌های موردنظر
mkdir -p /KDVpn/backend/templates
mkdir -p /KDVpn/backend/static/css

# انتقال فایل‌های مشخص‌شده
mv ap.py /KDVpn/backend/
mv styles.css /KDVpn/backend/static/css/

# انتقال فایل‌های HTML به مسیر templates
mv dashboard.html /KDVpn/backend/templates/
mv users.html /KDVpn/backend/templates/
mv domains.html /KDVpn/backend/templates/
mv settings.html /KDVpn/backend/templates/

# ایجاد سرویس XRay
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=XRay service
After=network.target

[Service]
ExecStart=/usr/local/xray/xray run
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target
EOF

# ایجاد سرویس Sing-box
cat <<EOF > /etc/systemd/system/sing-box.service
[Unit]
Description=Sing-box service
After=network.target

[Service]
ExecStart=/usr/local/sing-box/sing-box run
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target
EOF

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

# پایان نصب
echo "نصب و پیکربندی با موفقیت انجام شد!"
