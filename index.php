<!DOCTYPE html>
<html lang="fa">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>پنل مدیریت Kurdan</title>
    <link rel="stylesheet" href="styles.css">
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

    <script src="script.js"></script>
</body>
</html>
