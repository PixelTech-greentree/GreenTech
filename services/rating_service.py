"""
Rating and leaderboard service
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from typing import List, Optional
from datetime import datetime, timedelta

from models import User, Task, TaskCompletionLog, Tree, CheckIn
from schemas import LeaderboardItem, UserStatsResponse


class RatingService:
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_leaderboard(
        self,
        range_type: str = "7d",
        from_date: Optional[str] = None,
        to_date: Optional[str] = None
    ) -> List[LeaderboardItem]:
        """
        Get leaderboard sorted by:
        1. Task count (DESC)
        2. Points sum (DESC)
        """
        now = datetime.utcnow()
        
        # Determine range
        if range_type == "7d":
            since = now - timedelta(days=7)
        elif range_type == "30d":
            since = now - timedelta(days=30)
        elif range_type == "custom" and from_date:
            since = datetime.fromisoformat(from_date.replace('Z', ''))
        else:
            since = None
        
        # Build query
        if since:
            # Filter by date
            logs_subq = (
                select(
                    TaskCompletionLog.user_id,
                    func.count(TaskCompletionLog.id).label('task_count'),
                    func.sum(TaskCompletionLog.delta_points).label('points_sum')
                )
                .where(and_(
                    TaskCompletionLog.reason == 'task_completed',
                    TaskCompletionLog.created_at >= since
                ))
                .group_by(TaskCompletionLog.user_id)
                .subquery()
            )
            
            query = (
                select(User, logs_subq.c.task_count, logs_subq.c.points_sum)
                .outerjoin(logs_subq, User.id == logs_subq.c.user_id)
                .where(User.is_active == True)
                .order_by(
                    func.coalesce(logs_subq.c.task_count, 0).desc(),
                    func.coalesce(logs_subq.c.points_sum, 0).desc()
                )
            )
        else:
            # All time
            logs_subq = (
                select(
                    TaskCompletionLog.user_id,
                    func.count(TaskCompletionLog.id).label('task_count'),
                    func.sum(TaskCompletionLog.delta_points).label('points_sum')
                )
                .where(TaskCompletionLog.reason == 'task_completed')
                .group_by(TaskCompletionLog.user_id)
                .subquery()
            )
            
            query = (
                select(User, logs_subq.c.task_count, logs_subq.c.points_sum)
                .outerjoin(logs_subq, User.id == logs_subq.c.user_id)
                .where(User.is_active == True)
                .order_by(
                    func.coalesce(logs_subq.c.task_count, 0).desc(),
                    func.coalesce(logs_subq.c.points_sum, 0).desc()
                )
            )
        
        result = await self.db.execute(query)
        rows = result.all()
        
        leaderboard = []
        for rank, (user, task_count, points_sum) in enumerate(rows, 1):
            leaderboard.append(LeaderboardItem(
                user_id=user.id,
                full_name=user.full_name,
                avatar_url=user.avatar_url,
                task_count=int(task_count or 0),
                points_sum=int(points_sum or 0),
                rank=rank
            ))
        
        return leaderboard
    
    async def get_user_stats(self, user_id: str) -> UserStatsResponse:
        """Get user statistics"""
        # User
        user_q = select(User).where(User.id == user_id)
        user_r = await self.db.execute(user_q)
        user = user_r.scalar_one_or_none()
        
        if not user:
            raise ValueError("User not found")
        
        # Trees
        total_trees = await self.db.scalar(
            select(func.count(Tree.id)).where(Tree.user_id == user_id)
        ) or 0
        
        active_trees = await self.db.scalar(
            select(func.count(Tree.id)).where(and_(
                Tree.user_id == user_id,
                Tree.status == 'active'
            ))
        ) or 0
        
        # Checkins
        total_checkins = await self.db.scalar(
            select(func.count(CheckIn.id)).where(CheckIn.user_id == user_id)
        ) or 0
        
        # Tasks
        pending_tasks = await self.db.scalar(
            select(func.count(Task.id)).where(and_(
                Task.created_by_user_id == user_id,
                Task.status == 'pending'
            ))
        ) or 0
        
        completed_tasks = await self.db.scalar(
            select(func.count(Task.id)).where(and_(
                Task.created_by_user_id == user_id,
                Task.status == 'completed'
            ))
        ) or 0
        
        claimed_tasks = await self.db.scalar(
            select(func.count(Task.id)).where(and_(
                Task.assigned_user_id == user_id,
                Task.status == 'claimed'
            ))
        ) or 0
        
        return UserStatsResponse(
            user_id=user_id,
            total_points=user.total_points,
            total_trees=total_trees,
            active_trees=active_trees,
            total_checkins=total_checkins,
            pending_tasks=pending_tasks,
            completed_tasks=completed_tasks,
            claimed_tasks=claimed_tasks
        )
