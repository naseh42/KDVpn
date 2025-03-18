#!/bin/bash

echo "شروع نصب XRay و Sing-box ..."

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git python3-pip certbot python3-certbot-nginx nginx

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# باز کردن پورت‌های اضافی برای XRay و Sing-box
ufw allow 10086/tcp
ufw allow 10087/tcp
ufw allow 443/tcp

# دانلود و نصب XRay (در صورت عدم وجود)
if [ ! -f "/usr/local/bin/xray" ]; then
    wget https://github.com/XTLS/Xray-core/releases/download/v1.5.0/Xray-linux-amd64-1.5.0.tar.gz
    tar -zxvf Xray-linux-amd64-1.5.0.tar.gz
    mv xray /usr/local/bin/
    chmod +x /usr/local/bin/xray
else
    echo "XRay از قبل نصب شده است."
fi

# دانلود و نصب Sing-box (در صورت عدم وجود)
if [ ! -f "/usr/local/bin/sing-box" ]; then
    wget https://github.com/SagerNet/sing-box/releases/download/v1.0.0/sing-box-linux-amd64.tar.gz
    tar -zxvf sing-box-linux-amd64.tar.gz
    mv sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
else
    echo "Sing-box از قبل نصب شده است."
fi

# ایجاد سرویس‌ها برای XRay و Sing-box
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=XRay service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run
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
ExecStart=/usr/local/bin/sing-box run
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target
EOF

# فعال‌سازی و شروع سرویس‌ها
systemctl enable xray sing-box
systemctl start xray sing-box

# پیکربندی پایگاه‌داده MySQL
echo "شروع پیکربندی MySQL ..."
read -sp "Enter MySQL root password: " mysql_root_password
mysql -e "CREATE DATABASE kurdan;"
mysql -e "CREATE USER 'kurdan_user'@'localhost' IDENTIFIED BY '$(openssl rand -base64 32)';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# پیکربندی XRay و Sing-box
mkdir -p /etc/xray /etc/sing-box

# ایجاد فایل‌های کانفیگ XRay و Sing-box
cat <<EOF > /etc/xray/config.json
{
  "inbounds": [
    {
      "port": 10086,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "$(uuidgen)", "alterId": 64}]
      }
    },
    {
      "port": 10087,
      "protocol": "hysteria",
      "settings": {
        "clients": [{"id": "$(uuidgen)", "alterId": 64}]
      }
    }
  ]
}
EOF

cat <<EOF > /etc/sing-box/config.json
{
  "log": {"level": "info", "output": "stdout"},
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {"address": "example.com", "port": 443, "users": [{"id": "$(uuidgen)", "alterId": 64}]}
        ]
      }
    },
    {
      "protocol": "xtcp",
      "settings": {
        "vnext": [
          {"address": "example.com", "port": 443, "users": [{"id": "$(uuidgen)", "alterId": 64}]}
        ]
      }
    }
  ]
}
EOF

# **نصب و راه‌اندازی FastAPI**
echo "نصب FastAPI و راه‌اندازی پنل Kurdan ..."
pip3 install fastapi uvicorn pymysql

# ایجاد فایل `requirements.txt`
cat <<EOF > /home/kurdan_project/KDVpn/requirements.txt
fastapi
uvicorn
pymysql
EOF

pip3 install -r /home/kurdan_project/KDVpn/requirements.txt

# ایجاد فایل `run.sh` برای اجرای FastAPI
cat <<EOF > /home/kurdan_project/KDVpn/run.sh
#!/bin/bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
EOF
chmod +x /home/kurdan_project/KDVpn/run.sh

# ایجاد سرویس برای FastAPI
cat <<EOF > /etc/systemd/system/kurdan_fastapi.service
[Unit]
Description=Kurdan FastAPI Service
After=network.target

[Service]
ExecStart=/usr/local/bin/uvicorn main:app --host 0.0.0.0 --port 8000
WorkingDirectory=/home/kurdan_project/KDVpn
User=www-data
Group=www-data
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable kurdan_fastapi
systemctl start kurdan_fastapi

# **پیکربندی SSL (اختیاری)**
read -p "آیا می‌خواهید اکنون گواهی SSL دریافت کنید؟ (y/n): " ssl_choice
if [[ "$ssl_choice" == "y" ]]; then
    read -p "نام دامنه خود را وارد کنید (مثلاً example.com): " domain_name
    certbot --nginx -d "$domain_name" --non-interactive --agree-tos --email your-email@example.com

    # تنظیمات Nginx برای SSL
    cat <<EOF > /etc/nginx/sites-available/$domain_name
server {
    listen 80;
    server_name $domain_name;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name $domain_name;

    ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
    systemctl reload nginx
    echo "گواهی SSL با موفقیت نصب شد!"
else
    echo "شما انتخاب کردید که گواهی SSL بعداً تنظیم شود."
fi

# **پایان نصب**
echo "نصب و راه‌اندازی با موفقیت انجام شد!"
