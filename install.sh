#!/bin/bash

# شروع نصب پیش‌نیازها
echo "🚀 شروع نصب پیش‌نیازها..."

# به‌روزرسانی سیستم
apt update && apt upgrade -y

# نصب پکیج‌های مورد نیاز
apt install -y wget curl ufw mysql-server git python3 python3-pip unzip jq nginx

# نصب Python و pip
echo "🔧 نصب پایتون و pip..."
apt install -y python3 python3-pip

# نصب پکیج‌های Python
pip3 install flask fastapi uvicorn

# نصب و پیکربندی فایروال
echo "⚙️ پیکربندی فایروال..."
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw enable

# دانلود و نصب XRay
echo "🔽 دانلود و نصب XRay..."
wget https://github.com/XTLS/Xray-core/releases/download/v1.5.0/Xray-linux-amd64-1.5.0.tar.gz
tar -zxvf Xray-linux-amd64-1.5.0.tar.gz
mv xray /usr/local/bin/
chmod +x /usr/local/bin/xray

# دانلود و نصب Sing-box
echo "🔽 دانلود و نصب Sing-box..."
wget https://github.com/SagerNet/sing-box/releases/download/v1.0.0/sing-box-linux-amd64.tar.gz
tar -zxvf sing-box-linux-amd64.tar.gz
mv sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box

# ایجاد سرویس‌ها برای XRay و Sing-box
echo "📋 ایجاد سرویس‌ها برای XRay و Sing-box..."

# سرویس XRay
echo "[Unit]
Description=XRay service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run
Restart=on-failure
User=nobody

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/xray.service

# سرویس Sing-box
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
echo "🔑 پیکربندی MySQL..."
read -sp "Enter MySQL root password: " mysql_root_password
mysql -e "CREATE DATABASE kurdan;"
mysql -e "CREATE USER 'kurdan_user'@'localhost' IDENTIFIED BY '${mysql_root_password}';"
mysql -e "GRANT ALL PRIVILEGES ON kurdan.* TO 'kurdan_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# پیکربندی XRay و Sing-box
echo "📁 تنظیمات اولیه XRay و Sing-box..."
mkdir -p /etc/xray
mkdir -p /etc/sing-box

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

# دانلود و نصب Nginx برای پنل وب
echo "🔧 نصب و پیکربندی Nginx..."
apt install -y nginx

# پیکربندی Nginx برای پنل
cat <<EOF > /etc/nginx/sites-available/kurdan
server {
    listen 80;
    server_name your-domain.com;
    root /var/www/html/kurdan;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# ایجاد لینک نرم‌افزاری برای فعال‌سازی سایت
ln -s /etc/nginx/sites-available/kurdan /etc/nginx/sites-enabled/
systemctl restart nginx

# ساخت پنل وب
echo "🎨 در حال ساخت پنل تحت وب..."

mkdir -p /var/www/html/kurdan

# فایل HTML پنل با چندین صفحه و دو زبانه
cat <<EOF > /var/www/html/kurdan/index.html
<!DOCTYPE html>
<html lang="fa">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>پنل مدیریت Kurdan</title>
    <link rel="stylesheet" href="style.css">
    <script src="script.js"></script>
</head>
<body>
    <div class="container">
        <header>
            <h1 id="title">پنل مدیریت Kurdan</h1>
            <button onclick="changeLanguage()">🌍 تغییر زبان</button>
        </header>
        
        <nav>
            <ul>
                <li onclick="showPage('dashboard')">🏠 <span id="nav-dashboard">داشبورد</span></li>
                <li onclick="showPage('users')">👤 <span id="nav-users">کاربران</span></li>
                <li onclick="showPage('domains')">🌍 <span id="nav-domains">دامنه‌ها</span></li>
                <li onclick="showPage('settings')">⚙️ <span id="nav-settings">تنظیمات</span></li>
            </ul>
        </nav>

        <section id="dashboard">
            <h2 id="dashboard-title">🏠 داشبورد</h2>
            <p id="dashboard-text">خوش آمدید به پنل مدیریت Kurdan</p>
        </section>

        <section id="users" class="hidden">
            <h2 id="users-title">👤 مدیریت کاربران</h2>
            <button onclick="addUser()">➕ افزودن کاربر</button>
            <ul id="user-list"></ul>
        </section>

        <section id="domains" class="hidden">
            <h2 id="domains-title">🌍 مدیریت دامنه‌ها</h2>
            <input type="text" id="domain-input" placeholder="نام دامنه را وارد کنید">
            <button onclick="addDomain()">➕ افزودن دامنه</button>
            <ul id="domain-list"></ul>
        </section>

        <section id="settings" class="hidden">
            <h2 id="settings-title">⚙️ تنظیمات</h2>
            <p>مدیریت تنظیمات XRay و Sing-box</p>
        </section>
    </div>
</body>
</html>
EOF

# استایل CSS
cat <<EOF > /var/www/html/kurdan/style.css
body {
    font-family: Arial, sans-serif;
    text-align: center;
    margin: 0;
    background: linear-gradient(to right, #4facfe, #00f2fe);
    color: white;
}
.container {
    width: 80%;
    margin: auto;
    padding: 20px;
}
header {
    display: flex;
    justify-content: space-between;
    background: rgba(0, 0, 0, 0.2);
    padding: 10px;
    border-radius: 10px;
}
nav ul {
    list-style: none;
    padding: 0;
}
nav li {
    display: inline;
    margin: 10px;
    cursor: pointer;
    font-weight: bold;
}
.hidden { display: none; }
button {
    padding: 10px;
    margin: 10px;
    background: #ff6f61;
    border: none;
    color: white;
    cursor: pointer;
}
EOF

# اسکریپت جاوااسکریپت
cat <<EOF > /var/www/html/kurdan/script.js
let lang = 'fa';

function showPage(pageId) {
    document.querySelectorAll('section').forEach(section => section.classList.add('hidden'));
    document.getElementById(pageId).classList.remove('hidden');
}

function changeLanguage() {
    lang = (lang === 'fa') ? 'en' : 'fa';
    document.getElementById('title').innerText = (lang === 'fa') ? 'پنل مدیریت Kurdan' : 'Kurdan Management Panel';
    document.getElementById('nav-dashboard').innerText = (lang === 'fa') ? 'داشبورد' : 'Dashboard';
    document.getElementById('nav-users').innerText = (lang === 'fa') ? 'کاربران' : 'Users';
    document.getElementById('nav-domains').innerText = (lang === 'fa') ? 'دامنه‌ها' : 'Domains';
    document.getElementById('nav-settings').innerText = (lang === 'fa') ? 'تنظیمات' : 'Settings';
    document.getElementById('dashboard-title').innerText = (lang === 'fa') ? '🏠 داشبورد' : '🏠 Dashboard';
    document.getElementById('dashboard-text').innerText = (lang === 'fa') ? 'خوش آمدید به پنل مدیریت Kurdan' : 'Welcome to Kurdan Management Panel';
}

function addUser() {
    let username = prompt("نام کاربر جدید را وارد کنید:");
    if (username) {
        let li = document.createElement("li");
        li.innerText = username;
        document.getElementById("user-list").appendChild(li);
    }
}

function addDomain() {
    let domain = document.getElementById("domain-input").value;
    if (domain) {
        let li = document.createElement("li");
        li.innerText = domain;
        document.getElementById("domain-list").appendChild(li);
        alert("دامنه " + domain + " اضافه شد!");
    }
}
EOF

# پایان نصب
echo "✅ نصب و پیکربندی پنل Kurdan با موفقیت انجام شد!"
