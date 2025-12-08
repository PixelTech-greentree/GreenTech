"""
SQLAlchemy models with segments support
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
    
    # Credentials
    phone_number = Column(String, unique=True, nullable=False, index=True)
    full_name = Column(String, nullable=False)
    password_hash = Column(String, nullable=False)
    
    # Profile
    avatar_url = Column(String, nullable=True)
    total_points = Column(Integer, default=0)
    
    # Status
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)
    
    # Relationships
    trees = relationship("Tree", back_populates="user", foreign_keys="Tree.user_id")
    checkins = relationship("CheckIn", back_populates="user")
    created_tasks = relationship("Task", back_populates="creator", foreign_keys="Task.created_by_user_id")
    assigned_tasks = relationship("Task", back_populates="assigned_user", foreign_keys="Task.assigned_user_id")
    completion_logs = relationship("TaskCompletionLog", back_populates="user")


class Tree(Base):
    __tablename__ = "trees"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Original GPS from user photo
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    
    # Centroid from segments (for distance calculations)
    centroid_lat = Column(Float, nullable=True, index=True)
    centroid_lon = Column(Float, nullable=True, index=True)
    
    # Polygon segments from satellite image
    # [[lat1, lon1], [lat2, lon2], ...]
    segments = Column(JSON, nullable=True)
    
    # Tree characteristics
    phase = Column(String, default="seedling")  # seedling, young, mature
    status = Column(String, default="active", index=True)  # active, dead, rejected
    
    # Latest AI analysis
    last_health = Column(String, nullable=True)  # healthy, stressed, critical
    last_soil_moisture = Column(String, nullable=True)  # dry, normal, wet
    last_analysis_at = Column(DateTime, nullable=True)
    
    # Bonus tracking
    initial_bonus_awarded = Column(Boolean, default=False)
    
    # Relationships
    user = relationship("User", back_populates="trees", foreign_keys=[user_id])
    checkins = relationship("CheckIn", back_populates="tree")
    tasks = relationship("Task", back_populates="tree")


class CheckIn(Base):
    __tablename__ = "checkins"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    tree_id = Column(String, ForeignKey("trees.id"), nullable=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    
    # Image data
    image_path = Column(String, nullable=False)
    image_hash = Column(String, nullable=False, index=True)
    perceptual_hash = Column(String, nullable=False, index=True)
    
    # Location
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    
    # Timestamps
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    client_timestamp = Column(String, nullable=True)
    
    # Check-in type
    type = Column(String, nullable=False)  # planting, watering, monitoring
    
    # AI Analysis results
    ai_raw_response = Column(JSON, nullable=True)
    ai_tree = Column(Boolean, nullable=True)
    ai_real_photo = Column(Boolean, nullable=True)
    ai_seedling = Column(Boolean, nullable=True)
    ai_maturity = Column(String, nullable=True)
    ai_health = Column(String, nullable=True)
    ai_soil_moisture = Column(String, nullable=True)
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
    
    # Ownership
    created_by_user_id = Column(String, ForeignKey("users.id"), nullable=False)
    assigned_user_id = Column(String, ForeignKey("users.id"), nullable=True)
    
    # Task details
    type = Column(String, nullable=False)  # watering, photo_check, closeup, clean_area
    status = Column(String, default="pending", index=True)  # pending, claimed, completed, rejected, off
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    due_date = Column(DateTime, nullable=False, index=True)
    completed_at = Column(DateTime, nullable=True)
    claimed_at = Column(DateTime, nullable=True)
    
    # Points
    reward_points = Column(Integer, default=0)
    penalty_points = Column(Integer, default=0)
    
    # Description
    description = Column(Text, nullable=True)
    
    # Relationships
    tree = relationship("Tree", back_populates="tasks")
    creator = relationship("User", back_populates="created_tasks", foreign_keys=[created_by_user_id])
    assigned_user = relationship("User", back_populates="assigned_tasks", foreign_keys=[assigned_user_id])


class TaskCompletionLog(Base):
    __tablename__ = "task_completion_logs"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    task_id = Column(String, ForeignKey("tasks.id"), nullable=False)
    
    delta_points = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    reason = Column(String, nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="completion_logs")
