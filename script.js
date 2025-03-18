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
};
