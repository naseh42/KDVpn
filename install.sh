#!/bin/bash

# نصب پیش‌نیازها
echo "شروع نصب پیش‌نیازها ..."
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git nginx jq

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# دانلود و نصب XRay
echo "در حال دانلود XRay ..."
XRay_LATEST=$(wget -qO- "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | jq -r .assets[0].browser_download_url)
wget $XRay_LATEST -O /tmp/XRay-linux-amd64-latest.tar.gz

# بررسی دانلود موفقیت‌آمیز XRay
if [ ! -f "/tmp/XRay-linux-amd64-latest.tar.gz" ]; then
    echo "خطا در دانلود XRay"
    exit 1
fi

tar -zxvf /tmp/XRay-linux-amd64-latest.tar.gz -C /tmp
mv /tmp/xray /usr/local/bin/
chmod +x /usr/local/bin/xray

# دانلود و نصب Sing-box
echo "در حال دانلود Sing-box ..."
SingBox_LATEST=$(wget -qO- "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .assets[0].browser_download_url)
wget $SingBox_LATEST -O /tmp/sing-box-linux-amd64-latest.tar.gz

# بررسی دانلود موفقیت‌آمیز Sing-box
if [ ! -f "/tmp/sing-box-linux-amd64-latest.tar.gz" ]; then
    echo "خطا در دانلود Sing-box"
    exit 1
fi

tar -zxvf /tmp/sing-box-linux-amd64-latest.tar.gz -C /tmp
mv /tmp/sing-box /usr/local/bin/
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

# فعال‌سازی سرویس‌ها
systemctl enable xray
systemctl enable sing-box
systemctl start xray
systemctl start sing-box

# پیکربندی پایگاه‌داده MySQL
echo "شروع پیکربندی MySQL ..."
read -sp "Enter MySQL root password: " mysql_root_password
mysql -e "CREATE DATABASE kurdan;"
mysql -e "CREATE USER 'kurdan_user'@'localhost' IDENTIFIED BY '${mysql_root_password}';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# پیکربندی XRay و Sing-box
echo "در حال تنظیم فایل‌های پیکربندی XRay و Sing-box ..."
mkdir -p /etc/xray
mkdir -p /etc/sing-box

# تنظیمات اولیه XRay
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
  }]
}" > /etc/xray/config.json

# تنظیمات اولیه Sing-box
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

# ساخت دایرکتوری‌های پنل Kurdan
echo "ساخت دایرکتوری‌ها برای پنل Kurdan ..."
mkdir -p /var/www/html/kurdan/templates
mkdir -p /var/www/html/kurdan/static/css

# انتقال فایل‌ها به مسیرهای صحیح
echo "انتقال فایل‌ها به دایرکتوری‌های مناسب ..."
cp /path/to/dashboard.html /var/www/html/kurdan/templates/
cp /path/to/users.html /var/www/html/kurdan/templates/
cp /path/to/domains.html /var/www/html/kurdan/templates/
cp /path/to/settings.html /var/www/html/kurdan/templates/
cp /path/to/styles.css /var/www/html/kurdan/static/css/

# پیکربندی Nginx
echo "پیکربندی Nginx برای دسترسی به پنل ..."
cat <<EOF > /etc/nginx/sites-available/kurdan
server {
    listen 80;
    server_name example.com;

    root /var/www/html/kurdan;

    location / {
        try_files \$uri /index.html;
    }
}
EOF

ln -s /etc/nginx/sites-available/kurdan /etc/nginx/sites-enabled/
systemctl restart nginx

# نصب Gunicorn
echo "نصب Gunicorn ..."
pip install gunicorn

# پیکربندی Gunicorn برای اجرای اپلیکیشن پنل
cat <<EOF > /etc/systemd/system/kurdan.service
[Unit]
Description=Kurdan Panel
After=network.target

[Service]
ExecStart=/usr/local/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 app:app
WorkingDirectory=/path/to/KDVpn/backend
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOF

# فعال‌سازی و شروع سرویس Gunicorn
systemctl enable kurdan
systemctl start kurdan

# پایان نصب
echo "نصب و پیکربندی پنل Kurdan با موفقیت انجام شد!"
