#!/bin/bash

# 1. بررسی و نصب پیش‌نیازها
echo "شروع نصب پیش‌نیازها ..."
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git unzip

# 2. بررسی و نصب XRay
echo "بررسی وجود XRay ..."
if ! command -v xray &> /dev/null; then
    echo "XRay یافت نشد. دانلود و نصب XRay ..."
    wget https://github.com/XTLS/Xray-core/releases/download/v1.5.0/Xray-linux-amd64-1.5.0.zip -O /root/Xray-linux-64.zip
    unzip /root/Xray-linux-64.zip -d /usr/local/xray
    chmod +x /usr/local/xray/xray
    rm /root/Xray-linux-64.zip
    echo "XRay نصب شد."
else
    echo "XRay قبلاً نصب شده است."
fi

# 3. بررسی و نصب Sing-box
echo "بررسی وجود Sing-box ..."
if ! command -v sing-box &> /dev/null; then
    echo "Sing-box یافت نشد. دانلود و نصب Sing-box ..."
    wget https://github.com/SagerNet/sing-box/releases/download/v1.11.5/sing-box-linux-amd64.tar.gz -O /root/sing-box-linux-64.tar.gz
    tar -zxvf /root/sing-box-linux-64.tar.gz -C /usr/local/
    chmod +x /usr/local/sing-box/sing-box
    rm /root/sing-box-linux-64.tar.gz
    echo "Sing-box نصب شد."
else
    echo "Sing-box قبلاً نصب شده است."
fi

# 4. بررسی و ساخت پوشه‌ها
echo "بررسی پوشه‌ها و ساخت پوشه‌های لازم ..."
mkdir -p /root/KDVpn/backend /root/KDVpn/backend/templates /root/KDVpn/backend/static/css

# 5. انتقال فایل‌های HTML به پوشه templates
echo "انتقال فایل‌های HTML به پوشه templates ..."
for file in /root/KDVpn/*.html; do
    if [[ -f $file ]]; then
        mv "$file" /root/KDVpn/backend/templates/
        echo "انتقال فایل HTML: $file"
    fi
done

# 6. انتقال فایل‌های Python به پوشه backend
echo "انتقال فایل‌های Python به پوشه backend ..."
for file in /root/KDVpn/*.py; do
    if [[ -f $file ]]; then
        mv "$file" /root/KDVpn/backend/
        echo "انتقال فایل Python: $file"
    fi
done

# 7. انتقال فایل‌های CSS به پوشه static/css
echo "انتقال فایل‌های CSS به پوشه static/css ..."
for file in /root/KDVpn/*.css; do
    if [[ -f $file ]]; then
        mv "$file" /root/KDVpn/backend/static/css/
        echo "انتقال فایل CSS: $file"
    fi
done

# 8. پیکربندی MySQL
echo "شروع پیکربندی MySQL ..."
read -sp "Enter MySQL root password: " mysql_root_password
mysql -u root -p"${mysql_root_password}" -e "CREATE DATABASE IF NOT EXISTS kurdan;"
mysql -u root -p"${mysql_root_password}" -e "CREATE USER IF NOT EXISTS 'kurdan_user'@'localhost' IDENTIFIED BY '${mysql_root_password}';"
mysql -u root -p"${mysql_root_password}" -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -u root -p"${mysql_root_password}" -e "FLUSH PRIVILEGES;"

# 9. پیکربندی XRay و Sing-box
echo "پیکربندی XRay و Sing-box ..."
mkdir -p /etc/xray /etc/sing-box

# کانفیگ XRay
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

# کانفیگ Sing-box
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
      'address': 'example.com',
      'port': 443,
      'users': [{
        'id': 'uuid-generated-here',
        'alterId': 64
      }]
    }
  }]
}" > /etc/sing-box/config.json

# 10. راه‌اندازی XRay و Sing-box
echo "فعال‌سازی سرویس‌ها ..."
systemctl enable xray
systemctl enable sing-box
systemctl start xray
systemctl start sing-box

echo "تمامی مراحل با موفقیت به پایان رسید!"
