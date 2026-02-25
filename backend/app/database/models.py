from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import datetime
import os

from app.utils.config import settings

SQLALCHEMY_DATABASE_URL = settings.DATABASE_URL

# PostgreSQL does not need check_same_thread
engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

class LessonPlan(Base):
    __tablename__ = "lesson_plans"

    id = Column(Integer, primary_key=True, index=True)
    teacher_id = Column(String, nullable=False, index=True)
    grade = Column(String, nullable=False, index=True)
    subject = Column(String, nullable=False, index=True)
    topic = Column(String, nullable=False)
    num_lectures = Column(Integer, nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class Worksheet(Base):
    __tablename__ = "worksheets"

    id = Column(Integer, primary_key=True, index=True)
    teacher_id = Column(String, nullable=False, index=True)
    grade = Column(String, nullable=False, index=True, server_default="")
    subject = Column(String, nullable=False, index=True, server_default="")
    title = Column(String, nullable=True)           # user-editable display name
    topic = Column(String, nullable=False)
    difficulty = Column(String, nullable=False)
    question_type = Column(String, nullable=False)
    num_questions = Column(Integer, nullable=False)
    content = Column(Text, nullable=False)
    plan_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
