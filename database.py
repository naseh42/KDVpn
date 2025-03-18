from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from decouple import config  # برای خواندن متغیرها از فایل .env

# خواندن اطلاعات اتصال به دیتابیس از فایل .env
DB_USERNAME = config("DB_USERNAME")
DB_PASSWORD = config("DB_PASSWORD")
DB_HOST = config("DB_HOST")
DB_PORT = config("DB_PORT")
DB_NAME = config("DB_NAME")

# ایجاد رشته اتصال به MySQL
DATABASE_URL = f"mysql+pymysql://{DB_USERNAME}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# تنظیمات SQLAlchemy
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# تابع برای مدیریت Session‌ها
def get_db():
    """ایجاد یک Session و مدیریت آن."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
