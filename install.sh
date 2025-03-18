#!/bin/bash

echo "شروع نصب XRay و Sing-box ..."

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git python3-pip python3-venv certbot python3-certbot-nginx nginx

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw allow 10086/tcp
ufw allow 10087/tcp
ufw enable

# دریافت جدیدترین نسخه XRay و Sing-box
LATEST_XRAY=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)
LATEST_SING_BOX=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | cut -d '"' -f 4)

# نصب XRay در صورت عدم وجود یا نسخه قدیمی‌تر
if [ ! -f "/usr/local/bin/xray" ] || [ "$(xray -version | head -n 1 | awk '{print $2}')" != "$LATEST_XRAY" ]; then
    wget https://github.com/XTLS/Xray-core/releases/download/${LATEST_XRAY}/Xray-linux-amd64.tar.gz
    tar -zxvf Xray-linux-amd64.tar.gz
    mv xray /usr/local/bin/
    chmod +x /usr/local/bin/xray
else
    echo "XRay نسخه‌ی جدید نصب است."
fi

# نصب Sing-box در صورت عدم وجود یا نسخه قدیمی‌تر
if [ ! -f "/usr/local/bin/sing-box" ] || [ "$(sing-box version | head -n 1 | awk '{print $2}')" != "$LATEST_SING_BOX" ]; then
    wget https://github.com/SagerNet/sing-box/releases/download/${LATEST_SING_BOX}/sing-box-linux-amd64.tar.gz
    tar -zxvf sing-box-linux-amd64.tar.gz
    mv sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
else
    echo "Sing-box نسخه‌ی جدید نصب است."
fi

# ایجاد سرویس‌های XRay و Sing-box
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=XRay service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run
Restart=always
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
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF

# راه‌اندازی مجدد سرویس‌ها
systemctl daemon-reload
systemctl enable --now xray sing-box

# پیکربندی پایگاه‌داده MySQL
echo "شروع پیکربندی MySQL ..."
read -sp "Enter MySQL root password: " mysql_root_password
mysql -e "CREATE DATABASE IF NOT EXISTS kurdan;"
mysql -e "CREATE USER IF NOT EXISTS 'kurdan_user'@'localhost' IDENTIFIED BY '$(openssl rand -base64 32)';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# تنظیمات اولیه XRay و Sing-box
mkdir -p /etc/xray /etc/sing-box

UUID_1=$(uuidgen)
UUID_2=$(uuidgen)

cat <<EOF > /etc/xray/config.json
{
  "inbounds": [
    {
      "port": 10086,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "$UUID_1", "alterId": 64}]
      }
    },
    {
      "port": 10087,
      "protocol": "hysteria",
      "settings": {
        "clients": [{"id": "$UUID_2", "alterId": 64}]
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
          {"address": "example.com", "port": 443, "users": [{"id": "$UUID_1", "alterId": 64}]}
        ]
      }
    }
  ]
}
EOF

# **نصب FastAPI در محیط مجازی**
echo "نصب FastAPI و راه‌اندازی پنل Kurdan ..."
mkdir -p /home/kurdan_project/KDVpn
cd /home/kurdan_project/KDVpn
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# بررسی وجود فایل requirements.txt
if [ -f "requirements.txt" ]; then
    echo "فایل requirements.txt موجود است، جایگزین می‌شود."
    rm requirements.txt
fi

cat <<EOF > requirements.txt
fastapi
uvicorn
pymysql
EOF

pip install -r requirements.txt

# ایجاد فایل اجرای FastAPI
cat <<EOF > run.sh
#!/bin/bash
source venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
EOF
chmod +x run.sh

# ایجاد سرویس FastAPI
cat <<EOF > /etc/systemd/system/kurdan_fastapi.service
[Unit]
Description=Kurdan FastAPI Service
After=network.target

[Service]
ExecStart=/home/kurdan_project/KDVpn/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
WorkingDirectory=/home/kurdan_project/KDVpn
User=www-data
Group=www-data
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now kurdan_fastapi

# **پیکربندی SSL اختیاری**
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

# **تنظیم Nginx Reverse Proxy پیش‌فرض**
cat <<EOF > /etc/nginx/sites-available/kurdan
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -s /etc/nginx/sites-available/kurdan /etc/nginx/sites-enabled/
systemctl reload nginx

# **پایان نصب**
echo "نصب و راه‌اندازی با موفقیت انجام شد!"
