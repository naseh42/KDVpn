from fastapi import FastAPI, APIRouter, Depends
from sqlalchemy.orm import Session
from routers import models, database, schemas

router = APIRouter()

# اضافه کردن کاربر جدید
@router.post("/users")
def create_user(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    db_user = models.User(
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
def update_user(user_id: int, user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
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

# ایجاد شیء FastAPI
app = FastAPI()

# اضافه کردن روت‌های تعریف‌شده
app.include_router(router)
