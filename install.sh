#!/bin/bash

# تنظیمات اولیه
KDVpn_dir="/root/KDVpn"
xray_version="v1.5.0"
singbox_version="v1.11.5"

# بررسی نصب XRay و Sing-box
echo "بررسی وجود XRay و Sing-box ..."
if ! command -v xray &> /dev/null; then
    echo "XRay نصب نشده است. در حال دانلود ..."
    wget "https://github.com/XTLS/Xray-core/releases/download/$xray_version/Xray-linux-amd64-$xray_version.tar.gz" -P $KDVpn_dir
    tar -zxvf "$KDVpn_dir/Xray-linux-amd64-$xray_version.tar.gz" -C /usr/local/bin/
    chmod +x /usr/local/bin/xray
    echo "XRay نصب شد."
else
    echo "XRay قبلاً نصب شده است."
fi

if ! command -v sing-box &> /dev/null; then
    echo "Sing-box نصب نشده است. در حال دانلود ..."
    wget "https://github.com/SagerNet/sing-box/releases/download/$singbox_version/sing-box-linux-amd64-$singbox_version.tar.gz" -P $KDVpn_dir
    tar -zxvf "$KDVpn_dir/sing-box-linux-amd64-$singbox_version.tar.gz" -C /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    echo "Sing-box نصب شد."
else
    echo "Sing-box قبلاً نصب شده است."
fi

# پیکربندی فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# پیکربندی MySQL بدون درخواست پسورد از کاربر
echo "شروع پیکربندی MySQL ..."
mysql_root_password=$(openssl rand -base64 12)
mysql -e "CREATE DATABASE kurdan;"
mysql -e "CREATE USER 'kurdan_user'@'localhost' IDENTIFIED BY '${mysql_root_password}';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# بررسی وجود فایل‌ها و انتقال آنها
echo "بررسی پوشه‌ها و ساخت پوشه‌های لازم ..."

# ایجاد پوشه‌ها در صورت عدم وجود
mkdir -p /usr/local/bin/xray
mkdir -p /usr/local/bin/sing-box
mkdir -p /etc/xray
mkdir -p /etc/sing-box
mkdir -p /root/KDVpn/templates
mkdir -p /root/KDVpn/backend
mkdir -p /root/KDVpn/static/css

# انتقال فایل‌ها به پوشه‌های مناسب فقط اگر وجود داشته باشند
[ -f "$KDVpn_dir/dashboard.html" ] && mv "$KDVpn_dir/dashboard.html" /root/KDVpn/templates/ && echo "فایل dashboard.html به پوشه templates منتقل شد."
[ -f "$KDVpn_dir/users.html" ] && mv "$KDVpn_dir/users.html" /root/KDVpn/templates/ && echo "فایل users.html به پوشه templates منتقل شد."
[ -f "$KDVpn_dir/domains.html" ] && mv "$KDVpn_dir/domains.html" /root/KDVpn/templates/ && echo "فایل domains.html به پوشه templates منتقل شد."
[ -f "$KDVpn_dir/settings.html" ] && mv "$KDVpn_dir/settings.html" /root/KDVpn/templates/ && echo "فایل settings.html به پوشه templates منتقل شد."
[ -f "$KDVpn_dir/main.py" ] && mv "$KDVpn_dir/main.py" /root/KDVpn/backend/ && echo "فایل main.py به پوشه backend منتقل شد."
[ -f "$KDVpn_dir/styles.css" ] && mv "$KDVpn_dir/styles.css" /root/KDVpn/static/css/ && echo "فایل styles.css به پوشه static/css منتقل شد."

# پیکربندی XRay و Sing-box
echo "Setting up XRay and Sing-box configs ..."

# تنظیمات اولیه XRay
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

# تنظیمات اولیه Sing-box
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

# فعال‌سازی و راه‌اندازی سرویس‌ها
systemctl enable xray
systemctl enable sing-box
systemctl start xray
systemctl start sing-box

echo "تمامی مراحل با موفقیت به پایان رسید!"
