#!/bin/bash

# مراحل نصب و پیکربندی XRay و Sing-box و FastAPI
echo "شروع نصب پیش‌نیازها ..."

# نصب پیش‌نیازها
apt update && apt upgrade -y
apt install -y wget curl ufw mysql-server git python3-pip python3-dev

# نصب FastAPI و سایر وابستگی‌ها
pip3 install fastapi uvicorn mysql-connector pydantic

# تنظیمات فایروال
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# دانلود و نصب XRay
echo "دانلود و نصب XRay ..."
wget https://github.com/XTLS/Xray-core/releases/download/v1.5.0/Xray-linux-amd64-1.5.0.tar.gz
tar -zxvf Xray-linux-amd64-1.5.0.tar.gz
mv xray /usr/local/bin/
chmod +x /usr/local/bin/xray

# دانلود و نصب Sing-box
echo "دانلود و نصب Sing-box ..."
wget https://github.com/SagerNet/sing-box/releases/download/v1.0.0/sing-box-linux-amd64.tar.gz
tar -zxvf sing-box-linux-amd64.tar.gz
mv sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box

# ایجاد سرویس‌ها برای XRay و Sing-box
echo "ایجاد سرویس‌ها برای XRay و Sing-box ..."
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

# پیکربندی XRay و Sing-box
echo "تنظیمات اولیه برای XRay و Sing-box ..."

# تنظیمات اولیه XRay
mkdir -p /etc/xray
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
mkdir -p /etc/sing-box
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

# نصب سرویس‌های لازم برای پروژه
echo "نصب و راه‌اندازی FastAPI ..."
# راه‌اندازی FastAPI با Uvicorn
systemctl enable uvicorn
systemctl start uvicorn

# تنظیمات اولیه برای FastAPI و اتصال به MySQL
echo "تنظیمات اولیه برای FastAPI ..."
echo "import mysql.connector
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List

app = FastAPI()

# اتصال به دیتابیس
def get_db_connection():
    connection = mysql.connector.connect(
        host='localhost',
        user='kurdan_user',
        password='${mysql_root_password}',
        database='kurdan'
    )
    return connection

# مدل کاربر
class User(BaseModel):
    username: str
    uuid: str
    expiration_date: str
    usage: int

# ایجاد API برای مدیریت کاربران و سرورها
@app.get('/users', response_model=List[User])
def get_users():
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    cursor.execute('SELECT * FROM users')
    users = cursor.fetchall()
    connection.close()
    return users

@app.post('/users')
def add_user(user: User):
    connection = get_db_connection()
    cursor = connection.cursor()
    cursor.execute('INSERT INTO users (username, uuid, expiration_date, usage) VALUES (%s, %s, %s, %s)', 
                   (user.username, user.uuid, user.expiration_date, user.usage))
    connection.commit()
    connection.close()
    return {'message': 'User added successfully!'}

@app.delete('/users/{uuid}')
def delete_user(uuid: str):
    connection = get_db_connection()
    cursor = connection.cursor()
    cursor.execute('DELETE FROM users WHERE uuid = %s', (uuid,))
    connection.commit()
    connection.close()
    return {'message': 'User deleted successfully!'}
" > /etc/fastapi/main.py

# ایجاد محیط مجازی و نصب FastAPI در آن
python3 -m venv /etc/fastapi/venv
source /etc/fastapi/venv/bin/activate
pip install fastapi uvicorn mysql-connector pydantic

# راه‌اندازی سرویس FastAPI
systemctl restart uvicorn
systemctl enable uvicorn

echo "تمام مراحل نصب با موفقیت انجام شد!"
