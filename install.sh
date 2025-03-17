#!/bin/bash

# (بقیه قسمت‌های اسکریپت تغییر نکرده و ثابت هستند...)

# 🌐 ایجاد پنل تحت وب جدید و حرفه‌ای
echo "🎨 در حال ساخت پنل تحت وب حرفه‌ای..."

# مسیر پنل
mkdir -p /var/www/html/kurdan

# 🔹 فایل HTML پنل با چندین صفحه و دو زبانه
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

# 🔹 استایل حرفه‌ای CSS برای زیبایی پنل
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

# 🔹 اسکریپت جاوااسکریپت برای مدیریت صفحات و دو زبانه بودن
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

# 🎯 تنظیمات Nginx برای اجرای پنل
echo "🔧 پیکربندی Nginx برای پنل..."
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

ln -s /etc/nginx/sites-available/kurdan /etc/nginx/sites-enabled/
systemctl restart nginx

echo "✅ نصب پنل مدیریت Kurdan با موفقیت انجام شد!"
