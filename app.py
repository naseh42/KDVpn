from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

# تعریف FastAPI
app = FastAPI()

# تعریف مسیرهای قالب‌ها
templates = Jinja2Templates(directory="backend/templates")

# صفحه داشبورد
@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request, lang: str = "fa"):
    return templates.TemplateResponse("dashboard.html", {"request": request, "lang": lang})

# صفحه مدیریت کاربران
@app.get("/users", response_class=HTMLResponse)
async def users(request: Request, lang: str = "fa"):
    # دریافت داده‌های کاربران از پایگاه داده
    users = [
        {"name": "Ali", "uuid": "1234", "expiry": "2025-12-31"},
        {"name": "Reza", "uuid": "5678", "expiry": "2025-12-31"},
    ]
    return templates.TemplateResponse("users.html", {"request": request, "lang": lang, "users": users})

# صفحه مدیریت دامنه‌ها
@app.get("/domains", response_class=HTMLResponse)
async def domains(request: Request, lang: str = "fa"):
    # دریافت لیست دامنه‌ها از پایگاه داده
    domains = ["example.com", "test.com"]
    return templates.TemplateResponse("domains.html", {"request": request, "lang": lang, "domains": domains})

# صفحه تنظیمات
@app.get("/settings", response_class=HTMLResponse)
async def settings(request: Request, lang: str = "fa"):
    # در اینجا می‌توانید تنظیمات لازم را برگردانید
    settings_data = {
        "setting1": "value1",
        "setting2": "value2",
    }
    return templates.TemplateResponse("settings.html", {"request": request, "lang": lang, "settings": settings_data})
