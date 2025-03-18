#!/bin/bash

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl unzip tar ufw mysql-server git

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# مسیرهای اصلی
XRAY_DIR="/usr/local/xray"
SING_BOX_DIR="/usr/local/sing-box"

# دانلود و نصب Xray
echo "در حال دانلود Xray..."
XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
wget -O xray_download $XRAY_URL

# تشخیص فرمت و استخراج
if file xray_download | grep -q "Zip archive data"; then
    echo "فایل Xray به صورت ZIP است، در حال استخراج..."
    unzip xray_download -d $XRAY_DIR/
elif file xray_download | grep -q "gzip compressed data"; then
    echo "فایل Xray به صورت TAR است، در حال استخراج..."
    tar -xvzf xray_download -C $XRAY_DIR/
else
    echo "فرمت نامعتبر برای Xray! نصب متوقف شد."
    exit 1
fi

chmod +x $XRAY_DIR/xray

# دانلود و نصب Sing-box
echo "در حال دانلود Sing-box..."
SING_BOX_URL="https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz"
wget -O sing-box.tar.gz $SING_BOX_URL

if [ $? -eq 0 ]; then
    echo "در حال استخراج Sing-box..."
    mkdir -p $SING_BOX_DIR
    tar -xvzf sing-box.tar.gz -C $SING_BOX_DIR/
    chmod +x $SING_BOX_DIR/sing-box
else
    echo "خطا در دانلود Sing-box! لطفاً لینک را بررسی کنید."
    exit 1
fi

# ایجاد پوشه‌های موردنیاز
echo "بررسی و ایجاد پوشه‌های مورد نیاز..."
mkdir -p KDVpn/backend/templates
mkdir -p KDVpn/backend/static/css

# انتقال فایل‌ها به مسیرهای درست
echo "انتقال فایل‌ها..."
[ -f "app.py" ] && mv app.py KDVpn/backend/ || echo "فایل app.py یافت نشد!"
[ -f "users.html" ] && mv users.html KDVpn/backend/templates/ || echo "فایل users.html یافت نشد!"
[ -f "styles.css" ] && mv styles.css KDVpn/backend/static/css/ || echo "فایل styles.css یافت نشد!"

# پیکربندی یونیکورن
echo "تنظیم فایل unicorn.service..."
cat > /etc/systemd/system/unicorn.service <<EOF
[Unit]
Description=Gunicorn instance to serve Kurdan
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=/root/KDVpn/backend
ExecStart=/usr/bin/python3 /root/KDVpn/backend/app.py

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable unicorn
systemctl start unicorn

echo "✅ نصب و انتقال فایل‌ها کامل شد!"
