"""
User service for managing user data and statistics
"""
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func

from models import User, Task, Tree, CheckIn
from schemas import TaskSchema, UserStatsResponse


class UserService:
    
    def __init__(self, db: Session):
        self.db = db
    
    async def get_or_create_user(self, user_id: str) -> User:
        """Get existing user or create new one"""
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            user = User(id=user_id, total_points=0)
            self.db.add(user)
            self.db.commit()
            self.db.refresh(user)
        return user
    
    async def get_user_tasks(
        self, 
        user_id: str, 
        status: Optional[str] = None
    ) -> List[TaskSchema]:
        """
        Get all tasks for a user, optionally filtered by status
        """
        query = self.db.query(Task).filter(Task.user_id == user_id)
        
        if status:
            query = query.filter(Task.status == status)
        
        tasks = query.order_by(Task.due_date.asc()).all()
        
        return [TaskSchema.from_orm(task) for task in tasks]
    
    async def get_user_stats(self, user_id: str) -> UserStatsResponse:
        """
        Get comprehensive statistics for a user
        """
        user = await self.get_or_create_user(user_id)
        
        # Count trees
        total_trees = self.db.query(func.count(Tree.id)).filter(
            Tree.user_id == user_id
        ).scalar()
        
        active_trees = self.db.query(func.count(Tree.id)).filter(
            Tree.user_id == user_id,
            Tree.status == "active"
        ).scalar()
        
        # Count waterings (successful watering check-ins)
        total_waterings = self.db.query(func.count(CheckIn.id)).filter(
            CheckIn.user_id == user_id,
            CheckIn.type == "watering",
            CheckIn.accepted == True
        ).scalar()
        
        # Count total check-ins
        total_checkins = self.db.query(func.count(CheckIn.id)).filter(
            CheckIn.user_id == user_id
        ).scalar()
        
        # Count tasks
        pending_tasks = self.db.query(func.count(Task.id)).filter(
            Task.user_id == user_id,
            Task.status == "pending"
        ).scalar()
        
        completed_tasks = self.db.query(func.count(Task.id)).filter(
            Task.user_id == user_id,
            Task.status == "completed"
        ).scalar()
        
        return UserStatsResponse(
            user_id=user_id,
            total_points=user.total_points,
            total_trees=total_trees or 0,
            active_trees=active_trees or 0,
            total_waterings=total_waterings or 0,
            total_checkins=total_checkins or 0,
            pending_tasks=pending_tasks or 0,
            completed_tasks=completed_tasks or 0
        )
