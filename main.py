from fastapi import FastAPI, Depends
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from .models import User, Server
from .crud import get_users, get_servers
from .config import DATABASE_URL

app = FastAPI()

# دیتابیس
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@app.get("/users/")
def read_users(skip: int = 0, limit: int = 10, db: Session = Depends(get_db)):
    users = get_users(db, skip=skip, limit=limit)
    return users

@app.get("/servers/")
def read_servers(skip: int = 0, limit: int = 10, db: Session = Depends(get_db)):
    servers = get_servers(db, skip=skip, limit=limit)
    return servers

# راه‌اندازی دیتابیس
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
