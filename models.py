from sqlalchemy import Column, String, Integer, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime, timedelta
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, index=True)
    uuid = Column(String, unique=True, index=True)
    traffic_limit = Column(Integer)  # حجم مصرف
    usage_duration = Column(Integer)  # مدت زمان استفاده (روزها)
    expiry_date = Column(DateTime)  # تاریخ انقضا که محاسبه می‌شود از مدت زمان استفاده
    simultaneous_connections = Column(Integer)  # محدودیت اتصال همزمان
    active = Column(Boolean, default=True)  # وضعیت کاربر (فعال یا غیرفعال)
    
    server_id = Column(Integer, ForeignKey('servers.id'))
    server = relationship("Server", back_populates="users")

    def set_expiry_date(self):
        if self.usage_duration:
            self.expiry_date = datetime.utcnow() + timedelta(days=self.usage_duration)
