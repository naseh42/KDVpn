#!/bin/bash

# 1. تنظیمات اولیه
KDVpn_dir="/root/KDVpn"
xray_version="v1.5.0"
singbox_version="v1.11.4"

# 2. دریافت دامنه از کاربر (اختیاری)
read -p "لطفاً دامنه خود را وارد کنید (اختیاری): " domain_name
if [[ -z "$domain_name" ]]; then
    echo "هیچ دامنه‌ای وارد نشد. سرور با آدرس IP کار خواهد کرد."
    domain_name=""
else
    echo "دامنه تنظیم شد: $domain_name"
fi

# 3. بررسی نصب XRay
echo "بررسی نصب XRay ..."
if ! command -v xray &> /dev/null; then
    echo "XRay نصب نشده است. دانلود و نصب در حال انجام ..."
    wget "https://github.com/XTLS/Xray-core/releases/download/$xray_version/Xray-linux-64.zip" -P $KDVpn_dir
    unzip "$KDVpn_dir/Xray-linux-64.zip" -d /usr/local/bin/
    chmod +x /usr/local/bin/xray
    echo "XRay با موفقیت نصب شد."
else
    echo "XRay قبلاً نصب شده است."
fi

# 4. بررسی نصب Sing-box
echo "بررسی نصب Sing-box ..."
if ! command -v sing-box &> /dev/null; then
    echo "Sing-box نصب نشده است. دانلود و نصب در حال انجام ..."
    wget "https://github.com/SagerNet/sing-box/releases/download/$singbox_version/sing-box-linux-amd64-$singbox_version.tar.gz" -P $KDVpn_dir
    tar -zxvf "$KDVpn_dir/sing-box-linux-amd64-$singbox_version.tar.gz" -C /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    echo "Sing-box با موفقیت نصب شد."
else
    echo "Sing-box قبلاً نصب شده است."
fi

# 5. پیکربندی فایروال
echo "پیکربندی فایروال ..."
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# 6. نصب و پیکربندی MySQL
echo "پیکربندی MySQL ..."
mysql_root_password=$(openssl rand -base64 12)
mysql -e "CREATE DATABASE kurdan;"
mysql -e "CREATE USER 'kurdan_user'@'localhost' IDENTIFIED BY '${mysql_root_password}';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# 7. نصب و پیکربندی Unicorn
echo "نصب و راه‌اندازی Unicorn ..."
apt install -y ruby ruby-dev
gem install unicorn
echo "[Unit]
Description=Unicorn HTTP Server
After=network.target

[Service]
ExecStart=/usr/local/bin/unicorn -c /root/KDVpn/unicorn_config.rb -E production
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/unicorn.service
systemctl enable unicorn
systemctl start unicorn

# 8. نصب و پیکربندی Nginx
echo "نصب و راه‌اندازی Nginx ..."
apt install -y nginx
echo "server {
    listen 80;
    server_name ${domain_name:-_};

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}" > /etc/nginx/sites-available/kurdan
ln -s /etc/nginx/sites-available/kurdan /etc/nginx/sites-enabled/
systemctl enable nginx
systemctl restart nginx

# 9. نصب و پیکربندی SSL (Certbot)
if [[ -n "$domain_name" ]]; then
    echo "نصب و پیکربندی Certbot برای SSL ..."
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d $domain_name --non-interactive --agree-tos -m admin@$domain_name
    systemctl reload nginx
else
    echo "هیچ دامنه‌ای تنظیم نشده است، بخش SSL رد شد."
fi

# 10. ایجاد پوشه‌ها
echo "ایجاد پوشه‌های لازم ..."
mkdir -p /usr/local/bin/xray
mkdir -p /usr/local/bin/sing-box
mkdir -p /etc/xray
mkdir -p /etc/sing-box
mkdir -p /root/KDVpn/templates
mkdir -p /root/KDVpn/backend
mkdir -p /root/KDVpn/static/css

# 11. انتقال فایل‌ها
echo "انتقال فایل‌های لازم ..."
[ -f "$KDVpn_dir/dashboard.html" ] && mv "$KDVpn_dir/dashboard.html" /root/KDVpn/templates/
[ -f "$KDVpn_dir/users.html" ] && mv "$KDVpn_dir/users.html" /root/KDVpn/templates/
[ -f "$KDVpn_dir/domains.html" ] && mv "$KDVpn_dir/domains.html" /root/KDVpn/templates/
[ -f "$KDVpn_dir/app.py" ] && mv "$KDVpn_dir/app.py" /root/KDVpn/backend/

# 12. تولید UUID و پیکربندی XRay
uuid=$(cat /proc/sys/kernel/random/uuid)
echo "{
  \"inbounds\": [{
    \"port\": 10086,
    \"protocol\": \"vmess\",
    \"settings\": {
      \"clients\": [{
        \"id\": \"$uuid\",
        \"alterId\": 64
      }]
    }
  }]
}" > /etc/xray/config.json

# 13. پیکربندی Sing-box
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
          \"id\": \"$uuid\",
          \"alterId\": 64
        }]
      }]
    }
  }]
}" > /etc/sing-box/config.json

# 14. تنظیم مجوزها
echo "تنظیم مجوزها ..."
chmod -R 755 /root/KDVpn
chown -R www-data:www-data /root/KDVpn

# 15. فعال‌سازی سرویس‌ها
echo "فعال‌سازی و راه‌اندازی سرویس‌ها ..."
systemctl enable xray
systemctl enable sing-box
systemctl start xray
systemctl start sing-box

# پیام نهایی
echo "✅ تمامی مراحل نصب و پیکربندی با موفقیت به پایان رسید!"
