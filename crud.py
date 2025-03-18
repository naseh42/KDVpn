from sqlalchemy.orm import Session
from .models import User, Server

def get_users(db: Session, skip: int = 0, limit: int = 10):
    return db.query(User).offset(skip).limit(limit).all()

def get_servers(db: Session, skip: int = 0, limit: int = 10):
    return db.query(Server).offset(skip).limit(limit).all()
