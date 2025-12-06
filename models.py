"""
Database models for GreenTech Tree Tracking system
"""
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey, Text, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from database import Base


def generate_uuid():
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    
    # User credentials
    phone_number = Column(String, unique=True, nullable=False, index=True)
    full_name = Column(String, nullable=False)
    password_hash = Column(String, nullable=False)  # Hashed password
    
    # Profile info
    avatar_url = Column(String, nullable=True)
    total_points = Column(Integer, default=0)
    
    # Status
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)
    
    # Relationships
    trees = relationship("Tree", back_populates="user")
    checkins = relationship("CheckIn", back_populates="user")
    tasks = relationship("Task", back_populates="user")
    completion_logs = relationship("TaskCompletionLog", back_populates="user")


class Tree(Base):
    __tablename__ = "trees"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Location
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    
    # Tree characteristics
    phase = Column(String, default="seedling")  # seedling, young, mature
    status = Column(String, default="active")  # active, dead, rejected
    
    # Latest AI analysis
    last_health = Column(String, nullable=True)  # healthy, stressed, critical
    last_soil_moisture = Column(String, nullable=True)  # dry, normal, wet
    last_analysis_at = Column(DateTime, nullable=True)
    
    # Bonus tracking
    initial_bonus_awarded = Column(Boolean, default=False)
    successful_waterings = Column(Integer, default=0)
    
    # Relationships
    user = relationship("User", back_populates="trees")
    checkins = relationship("CheckIn", back_populates="tree")
    tasks = relationship("Task", back_populates="tree")


class CheckIn(Base):
    __tablename__ = "checkins"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    tree_id = Column(String, ForeignKey("trees.id"), nullable=True)  # Null for first planting
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    
    # Image data
    image_path = Column(String, nullable=False)
    image_hash = Column(String, nullable=False, index=True)
    perceptual_hash = Column(String, nullable=False, index=True)
    
    # Location
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    
    # Timestamps
    timestamp = Column(DateTime, default=datetime.utcnow)
    client_timestamp = Column(String, nullable=True)
    
    # Check-in type
    type = Column(String, nullable=False)  # planting, watering, monitoring
    
    # AI Analysis results
    ai_raw_response = Column(JSON, nullable=True)
    ai_seedling = Column(Boolean, nullable=True)
    ai_maturity = Column(String, nullable=True)  # seedling, young, mature, unknown
    ai_health = Column(String, nullable=True)  # healthy, stressed, critical, unknown
    ai_soil_moisture = Column(String, nullable=True)  # dry, normal, wet, unknown
    ai_comment = Column(Text, nullable=True)
    
    # Validation
    cheat_suspected = Column(Boolean, default=False)
    accepted = Column(Boolean, default=True)
    rejected_reason = Column(String, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="checkins")
    tree = relationship("Tree", back_populates="checkins")


class Task(Base):
    __tablename__ = "tasks"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    tree_id = Column(String, ForeignKey("trees.id"), nullable=False)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    
    # Task details
    type = Column(String, nullable=False)  # planting_photo, watering, photo_check, closeup_photo, clean_area
    status = Column(String, default="pending")  # pending, completed, rejected, off
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    due_date = Column(DateTime, nullable=False)
    completed_at = Column(DateTime, nullable=True)
    
    # Points
    reward_points = Column(Integer, default=0)
    penalty_points = Column(Integer, default=0)
    
    # Description for mobile app
    description = Column(Text, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="tasks")
    tree = relationship("Tree", back_populates="tasks")


class TaskCompletionLog(Base):
    __tablename__ = "task_completion_logs"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    task_id = Column(String, ForeignKey("tasks.id"), nullable=False)
    
    delta_points = Column(Integer, nullable=False)  # Can be positive or negative
    created_at = Column(DateTime, default=datetime.utcnow)
    reason = Column(String, nullable=False)  # task_completed, task_late_penalty, initial_bonus
    
    # Relationships
    user = relationship("User", back_populates="completion_logs")
