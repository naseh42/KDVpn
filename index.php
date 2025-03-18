<!DOCTYPE html>
<html lang="fa">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>پنل مدیریت Kurdan</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f9;
            margin: 0;
            padding: 0;
        }
        .container {
            width: 80%;
            margin: auto;
            padding-top: 50px;
        }
        .header {
            text-align: center;
            background-color: #34495e;
            color: white;
            padding: 20px;
            border-radius: 5px;
        }
        .button {
            background-color: #3498db;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }
        .button:hover {
            background-color: #2980b9;
        }
        ul {
            list-style-type: none;
            padding: 0;
        }
        li {
            background-color: #ecf0f1;
            padding: 10px;
            margin: 5px 0;
            border-radius: 5px;
        }
        .language-toggle {
            margin-top: 20px;
            background-color: #2ecc71;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }
        .language-toggle:hover {
            background-color: #27ae60;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>پنل مدیریت Kurdan</h1>
        </div>
        
        <h2>لیست کاربران:</h2>
        <ul id="user-list"></ul>
        <button class="button" onclick="addUser()">افزودن کاربر</button>
        
        <h2>دامنه‌ها:</h2>
        <ul id="domain-list"></ul>
        <input type="text" id="domain-input" placeholder="دامنه جدید را وارد کنید" />
        <button class="button" onclick="addDomain()">افزودن دامنه</button>

        <button class="language-toggle" onclick="changeLanguage()">تغییر زبان</button>
    </div>

    <script>
        let lang = 'fa';

        function changeLanguage() {
            lang = (lang === 'fa') ? 'en' : 'fa';
            document.title = (lang === 'fa') ? 'پنل مدیریت Kurdan' : 'Kurdan Management Panel';
            document.querySelector('.header h1').innerText = (lang === 'fa') ? 'پنل مدیریت Kurdan' : 'Kurdan Management Panel';
            document.querySelector('h2').innerText = (lang === 'fa') ? 'لیست کاربران:' : 'Users List:';
            document.querySelectorAll('button')[0].innerText = (lang === 'fa') ? 'افزودن کاربر' : 'Add User';
            document.querySelectorAll('button')[1].innerText = (lang === 'fa') ? 'افزودن دامنه' : 'Add Domain';
            document.querySelector('input').placeholder = (lang === 'fa') ? 'دامنه جدید را وارد کنید' : 'Enter new domain';
        }

        // افزودن کاربر
        function addUser() {
            const username = prompt((lang === 'fa') ? "نام کاربر جدید را وارد کنید:" : "Enter new username:");
            if (username) {
                let li = document.createElement("li");
                li.innerText = username;
                document.getElementById("user-list").appendChild(li);
                
                // ارسال داده‌ها به سرور
                fetch('/api/addUser', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ username: username })
                })
                .then(response => response.json())
                .then(data => console.log('User added:', data))
                .catch((error) => console.error('Error:', error));
            }
        }

        // افزودن دامنه
        function addDomain() {
            const domain = document.getElementById("domain-input").value;
            if (domain) {
                let li = document.createElement("li");
                li.innerText = domain;
                document.getElementById("domain-list").appendChild(li);
                alert((lang === 'fa') ? "دامنه " + domain + " اضافه شد!" : "Domain " + domain + " added!");
                
                // ارسال داده‌ها به سرور
                fetch('/api/addDomain', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ domain: domain })
                })
                .then(response => response.json())
                .then(data => console.log('Domain added:', data))
                .catch((error) => console.error('Error:', error));
            }
        }

        // بارگذاری داده‌های کاربران از سرور
        function loadUsers() {
            fetch('/api/getUsers')
                .then(response => response.json())
                .then(data => {
                    let userList = document.getElementById("user-list");
                    data.users.forEach(user => {
                        let li = document.createElement("li");
                        li.innerText = `${user.username} - ${user.email}`;
                        userList.appendChild(li);
                    });
                })
                .catch((error) => console.error('Error loading users:', error));
        }

        // بارگذاری داده‌های دامنه‌ها از سرور
        function loadDomains() {
            fetch('/api/getDomains')
                .then(response => response.json())
                .then(data => {
                    let domainList = document.getElementById("domain-list");
                    data.domains.forEach(domain => {
                        let li = document.createElement("li");
                        li.innerText = domain.domain_name;
                        domainList.appendChild(li);
                    });
                })
                .catch((error) => console.error('Error loading domains:', error));
        }

        // بارگذاری داده‌ها هنگام بارگذاری صفحه
        window.onload = () => {
            loadUsers();
            loadDomains();
        }
    </script>
</body>
</html>
