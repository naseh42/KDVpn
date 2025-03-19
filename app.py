from fastapi import FastAPI, APIRouter, Depends, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from backend.models import User
from backend.database import get_db
from backend.schemas import UserCreate

# ایجاد شیء FastAPI
app = FastAPI()

# تنظیم قالب‌ها (templates)
templates = Jinja2Templates(directory="backend/templates")

# اضافه کردن مسیر برای فایل‌های استاتیک
app.mount("/static", StaticFiles(directory="backend/static"), name="static")

# ایجاد روتر
router = APIRouter()

# مسیر پیش‌فرض: نمایش داشبورد
@app.get("/", response_class=HTMLResponse)
async def dashboard_page(request: Request):
    return templates.TemplateResponse("dashboard.html", {"request": request})

# مسیر کاربران: نمایش صفحه مدیریت کاربران
@app.get("/users", response_class=HTMLResponse)
async def users_page(request: Request):
    return templates.TemplateResponse("user.html", {"request": request})

# مسیر دامنه‌ها: نمایش صفحه مدیریت دامنه‌ها
@app.get("/domains", response_class=HTMLResponse)
async def domains_page(request: Request):
    return templates.TemplateResponse("domains.html", {"request": request})

# مسیر تنظیمات: نمایش صفحه تنظیمات
@app.get("/settings", response_class=HTMLResponse)
async def settings_page(request: Request):
    return templates.TemplateResponse("settings.html", {"request": request})

# اضافه کردن کاربر جدید
@router.post("/users")
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = User(
        username=user.username,
        uuid=user.uuid,
        traffic_limit=user.traffic_limit,
        usage_duration=user.usage_duration,
        simultaneous_connections=user.simultaneous_connections
    )
    db_user.set_expiry_date()  # محاسبه تاریخ انقضا
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

# ویرایش کاربر
@router.put("/users/{user_id}")
def update_user(user_id: int, user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.id == user_id).first()
    if db_user:
        db_user.username = user.username
        db_user.traffic_limit = user.traffic_limit
        db_user.usage_duration = user.usage_duration
        db_user.simultaneous_connections = user.simultaneous_connections
        db_user.set_expiry_date()  # به‌روز رسانی تاریخ انقضا
        db.commit()
        db.refresh(db_user)
        return db_user
    return {"message": "User not found"}

# اضافه کردن روترهای تعریف‌شده
app.include_router(router)
