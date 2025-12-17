"""
Statistics Service - Global tizim statistikasi
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from datetime import datetime, timedelta
from typing import Dict

from models import Tree, User, Task, CheckIn


class StatisticsService:
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_global_statistics(self) -> Dict:
        """
        Global tizim statistikasi
        """
        # Jami daraxtlar
        total_trees = await self.db.scalar(
            select(func.count(Tree.id))
        ) or 0
        
        # Faol daraxtlar
        active_trees = await self.db.scalar(
            select(func.count(Tree.id)).where(Tree.status == 'active')
        ) or 0
        
        # Jami userlar
        total_users = await self.db.scalar(
            select(func.count(User.id)).where(User.is_active == True)
        ) or 0
        
        # Bajarilgan vazifalar
        completed_tasks = await self.db.scalar(
            select(func.count(Task.id)).where(Task.status == 'completed')
        ) or 0
        
        # Jami sug'orishlar
        total_waterings = await self.db.scalar(
            select(func.count(CheckIn.id)).where(and_(
                CheckIn.type == 'watering',
                CheckIn.accepted == True
            ))
        ) or 0
        
        # O'rtacha salomatlik
        health_scores = {
            'excellent': 5,
            'healthy': 4,
            'stressed': 3,
            'critical': 2,
            'dying': 1
        }
        
        query = select(Tree.last_health).where(and_(
            Tree.status == 'active',
            Tree.last_health.isnot(None)
        ))
        result = await self.db.execute(query)
        healths = result.scalars().all()
        
        if healths:
            scores = [health_scores.get(h, 0) for h in healths]
            avg_health = sum(scores) / len(scores)
        else:
            avg_health = 0.0
        
        # Status bo'yicha
        status_query = select(
            Tree.status,
            func.count(Tree.id)
        ).group_by(Tree.status)
        status_result = await self.db.execute(status_query)
        trees_by_status = {row[0]: row[1] for row in status_result}
        
        # Yetuklik bo'yicha
        maturity_query = select(
            Tree.phase,
            func.count(Tree.id)
        ).where(Tree.status == 'active').group_by(Tree.phase)
        maturity_result = await self.db.execute(maturity_query)
        trees_by_maturity = {row[0]: row[1] for row in maturity_result}
        
        # Oxirgi 7 va 30 kun
        now = datetime.utcnow()
        seven_days_ago = now - timedelta(days=7)
        thirty_days_ago = now - timedelta(days=30)
        
        recent_7 = await self.db.scalar(
            select(func.count(Tree.id)).where(Tree.created_at >= seven_days_ago)
        ) or 0
        
        recent_30 = await self.db.scalar(
            select(func.count(Tree.id)).where(Tree.created_at >= thirty_days_ago)
        ) or 0
        
        return {
            "total_trees_planted": total_trees,
            "total_active_trees": active_trees,
            "total_users": total_users,
            "total_tasks_completed": completed_tasks,
            "total_waterings": total_waterings,
            "average_tree_health": round(avg_health, 2),
            "trees_by_status": trees_by_status,
            "trees_by_maturity": trees_by_maturity,
            "recent_plantings_7days": recent_7,
            "recent_plantings_30days": recent_30
        }
