from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

from dotenv import load_dotenv  # ⬅️ YANGI

# .env faylni yuklaymiz
load_dotenv()  # ⬅️ YANGI

# Endi DATABASE_URL har doim .env dan olinadi
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    # Minimal xavfsizlik: agar topilmasa, xato beramiz
    raise RuntimeError("DATABASE_URL is not set in environment or .env file")

# Engine yaratamiz
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {}
)

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()


def get_db():
    """
    Dependency for getting database session in FastAPI endpoints
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
