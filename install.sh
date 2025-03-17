#!/bin/bash

echo "🚀 شروع نصب XRay و Sing-box ..."

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git nginx certbot python3-certbot-nginx

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# دانلود و نصب XRay
XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip"
unzip xray.zip -d /usr/local/bin/
chmod +x /usr/local/bin/xray

# دانلود و نصب Sing-box
SING_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
wget -O sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/download/${SING_VERSION}/sing-box-linux-amd64.tar.gz"
tar -zxvf sing-box.tar.gz -C /usr/local/bin/
chmod +x /usr/local/bin/sing-box

# ایجاد سرویس‌ها
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=XRay service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/sing-box.service
[Unit]
Description=Sing-box service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target
EOF

# فعال‌سازی و اجرای سرویس‌ها
systemctl daemon-reload
systemctl enable xray sing-box
systemctl start xray sing-box

# تنظیم پایگاه‌داده
echo "📦 تنظیم پایگاه‌داده MySQL ..."
read -sp "Enter MySQL root password: " mysql_root_password
mysql -e "CREATE DATABASE kurdan;"
mysql -e "CREATE USER 'kurdan_user'@'localhost' IDENTIFIED BY '${mysql_root_password}';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# تنظیمات XRay و Sing-box
mkdir -p /etc/xray /etc/sing-box

cat <<EOF > /etc/xray/config.json
{
  "inbounds": [{
    "port": 10086,
    "protocol": "vmess",
    "settings": { "clients": [{ "id": "uuid-generated-here", "alterId": 64 }] }
  }]
}
EOF

cat <<EOF > /etc/sing-box/config.json
{
  "log": { "level": "info", "output": "stdout" },
  "outbounds": [{
    "protocol": "vmess",
    "settings": {
      "vnext": [{
        "address": "example.com",
        "port": 443,
        "users": [{ "id": "uuid-generated-here", "alterId": 64 }]
      }]
    }
  }]
}
EOF

systemctl restart xray sing-box

# نصب پنل تحت وب
echo "🌐 نصب پنل تحت وب ..."
git clone https://github.com/your-repo/kurdan-webpanel.git /var/www/html/kurdan
cd /var/www/html/kurdan
npm install

# تنظیم Nginx برای پنل
echo "🔧 پیکربندی Nginx ..."
read -p "لطفا دامنه خود را وارد کنید: " domain
cat <<EOF > /etc/nginx/sites-available/kurdan
server {
    listen 80;
    server_name $domain;
    root /var/www/html/kurdan;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -s /etc/nginx/sites-available/kurdan /etc/nginx/sites-enabled/
systemctl restart nginx

# دریافت و فعال‌سازی SSL
echo "🔐 دریافت گواهینامه SSL ..."
certbot --nginx -d $domain --non-interactive --agree-tos -m your-email@example.com

echo "✅ نصب کامل شد! لطفا به https://$domain مراجعه کنید."
