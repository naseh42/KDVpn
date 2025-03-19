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

# ایجاد روتر
router = APIRouter()

# تنظیم قالب‌ها (templates)
templates = Jinja2Templates(directory="backend/templates")

# اضافه کردن مسیر برای فایل‌های استاتیک
app.mount("/static", StaticFiles(directory="backend/static"), name="static")

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

# مسیر پیش‌فرض (ریشه)
@app.get("/")
def read_root():
    return {
        "message": "Welcome to KD VPN Backend"
    }

# مسیر نمایش صفحه تنظیمات (HTML)
@app.get("/settings", response_class=HTMLResponse)
async def settings_page(request: Request):
    return templates.TemplateResponse("settings.html", {"request": request})

# مسیر نمایش کاربران (HTML)
@app.get("/users", response_class=HTMLResponse)
async def users_page(request: Request):
    users = [
        {"name": "کاربر ۱", "uuid": "12345", "expiry": 30},
        {"name": "کاربر ۲", "uuid": "67890", "expiry": 15},
    ]
    return templates.TemplateResponse("user.html", {"request": request, "users": users})

# اضافه کردن روترهای تعریف‌شده
app.include_router(router)
