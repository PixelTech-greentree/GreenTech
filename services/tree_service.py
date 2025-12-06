"""
Tree service for managing tree data
"""
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func

from models import Tree, CheckIn, Task
from schemas import TreeDetailResponse, TreeBasicInfo, AIAnalysis, TaskSchema


class TreeService:
    
    def __init__(self, db: Session):
        self.db = db
    
    async def get_tree_detail(self, tree_id: str) -> Optional[TreeDetailResponse]:
        """
        Get detailed information about a tree
        """
        tree = self.db.query(Tree).filter(Tree.id == tree_id).first()
        
        if not tree:
            return None
        
        # Get last analysis
        last_checkin = self.db.query(CheckIn).filter(
            CheckIn.tree_id == tree_id,
            CheckIn.accepted == True
        ).order_by(CheckIn.timestamp.desc()).first()
        
        last_analysis = None
        if last_checkin and last_checkin.ai_raw_response:
            ai_data = last_checkin.ai_raw_response
            if isinstance(ai_data, dict):
                last_analysis = AIAnalysis(
                    is_seedling=ai_data.get("is_seedling", True),
                    maturity=ai_data.get("maturity", "unknown"),
                    health=ai_data.get("health", "unknown"),
                    soil_moisture=ai_data.get("soil_moisture", "unknown"),
                    comment=ai_data.get("comment") or ai_data.get("changes", "")
                )
        
        # Get pending tasks
        pending_tasks = self.db.query(Task).filter(
            Task.tree_id == tree_id,
            Task.status == "pending"
        ).order_by(Task.due_date.asc()).all()
        
        # Get completed tasks
        completed_tasks = self.db.query(Task).filter(
            Task.tree_id == tree_id,
            Task.status == "completed"
        ).order_by(Task.completed_at.desc()).limit(10).all()
        
        # Count total check-ins
        total_checkins = self.db.query(func.count(CheckIn.id)).filter(
            CheckIn.tree_id == tree_id
        ).scalar()
        
        return TreeDetailResponse(
            tree=TreeBasicInfo.from_orm(tree),
            last_analysis=last_analysis,
            pending_tasks=[TaskSchema.from_orm(t) for t in pending_tasks],
            completed_tasks=[TaskSchema.from_orm(t) for t in completed_tasks],
            total_checkins=total_checkins or 0
        )
    
    async def get_user_trees(
        self, 
        user_id: str, 
        status: Optional[str] = None
    ) -> List[TreeBasicInfo]:
        """
        Get all trees for a user, optionally filtered by status
        """
        query = self.db.query(Tree).filter(Tree.user_id == user_id)
        
        if status:
            query = query.filter(Tree.status == status)
        
        trees = query.order_by(Tree.created_at.desc()).all()
        
        return [TreeBasicInfo.from_orm(tree) for tree in trees]
