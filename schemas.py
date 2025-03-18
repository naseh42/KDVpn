from pydantic import BaseModel
from datetime import datetime

class UserBase(BaseModel):
    username: str
    uuid: str
    traffic_limit: int
    usage_duration: int  # مدت زمان استفاده (روزها)
    simultaneous_connections: int

class UserCreate(UserBase):
    pass

class User(UserBase):
    id: int
    expiry_date: datetime  # تاریخ انقضا به‌طور خودکار محاسبه می‌شود

    class Config:
        orm_mode = True
