#!/bin/bash

# مراحل نصب و پیکربندی XRay و Sing-box
echo "شروع نصب XRay و Sing-box ..."

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git nginx python3-pip python3-venv certbot python3-certbot-nginx

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

# ایجاد فایل SQL برای جداول دیتابیس
cat <<EOF > /root/kurdan-panel/init.sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    expire_date DATETIME NOT NULL,
    traffic_limit BIGINT NOT NULL,
    used_traffic BIGINT DEFAULT 0
);

CREATE TABLE servers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    ip VARCHAR(50) NOT NULL,
    status BOOLEAN DEFAULT TRUE
);
EOF

# اجرای اسکریپت SQL
mysql -u kurdan_user -p${mysql_root_password} kurdan < /root/kurdan-panel/init.sql

# پیکربندی XRay و Sing-box
mkdir -p /etc/xray
mkdir -p /etc/sing-box

# تنظیمات اولیه برای XRay و Sing-box
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
  }]
}" > /etc/xray/config.json

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
  }]
}" > /etc/sing-box/config.json

# راه‌اندازی سرویس‌های XRay و Sing-box
echo "راه‌اندازی سرویس‌های XRay و Sing-box ..."
systemctl daemon-reload
systemctl restart xray
systemctl restart sing-box

# نصب و راه‌اندازی FastAPI برای پنل Kurdan
echo "نصب و پیکربندی FastAPI ..."
mkdir -p /root/kurdan-panel
cd /root/kurdan-panel

python3 -m venv venv
source venv/bin/activate
pip install fastapi uvicorn mysql-connector-python

# ایجاد اسکریپت اجرای FastAPI
cat <<EOF > /root/kurdan-panel/run.sh
#!/bin/bash
cd /root/kurdan-panel
source venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
EOF

chmod +x /root/kurdan-panel/run.sh

# ایجاد سرویس `systemd` برای اجرای FastAPI
echo "[Unit]
Description=Kurdan Panel Service
After=network.target

[Service]
User=root
WorkingDirectory=/root/kurdan-panel
ExecStart=/root/kurdan-panel/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/kurdan.service

# فعال‌سازی و شروع پنل Kurdan
systemctl enable kurdan
systemctl start kurdan

# نصب و پیکربندی Nginx برای پنل Kurdan
echo "نصب و پیکربندی Nginx ..."
cat <<EOF > /etc/nginx/sites-available/kurdan
server {
    listen 80;

    server_name your_domain_or_ip;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# فعال‌سازی کانفیگ Nginx
ln -s /etc/nginx/sites-available/kurdan /etc/nginx/sites-enabled/
systemctl restart nginx

# تنظیم SSL برای Nginx (اختیاری)
read -p "آیا می‌خواهید SSL برای دامنه تنظیم کنید؟ (y/n): " enable_ssl
if [[ "\$enable_ssl" == "y" ]]; then
    read -p "دامنه خود را وارد کنید: " domain_name
    certbot --nginx -d \$domain_name
    systemctl restart nginx
    echo "SSL با موفقیت نصب شد!"
fi

# پایان نصب
echo "✅ نصب و پیکربندی با موفقیت انجام شد."
echo "🔗 لطفاً به پنل مدیریت Kurdan با استفاده از آدرس http://<server_ip> مراجعه کنید."
