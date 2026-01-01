"""
Enhanced Rating Service - Kengaytirilgan lider taxtasi
FIXED: Query errors
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, desc
from typing import List, Optional, Dict
from datetime import datetime, timedelta

from models import User, TaskCompletionLog, Tree, Task


class RatingEnhancedService:
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_enhanced_leaderboard(
        self,
        days: Optional[int] = None,
        limit: int = 50
    ) -> List[Dict]:
        """
        Kengaytirilgan lider taxtasi
        """
        now = datetime.utcnow()
        
        # Vaqt oralig'ini aniqlash
        since = None
        if days:
            since = now - timedelta(days=days)
        
        # Userlarni olish
        query = select(User).where(User.is_active == True)
        result = await self.db.execute(query)
        users = result.scalars().all()
        
        leaderboard = []
        
        for user in users:
            try:
                # Bajarilgan vazifalar
                if since:
                    tasks_q = select(func.count(TaskCompletionLog.id)).where(and_(
                        TaskCompletionLog.user_id == user.id,
                        TaskCompletionLog.reason == 'task_completed',
                        TaskCompletionLog.created_at >= since
                    ))
                else:
                    tasks_q = select(func.count(TaskCompletionLog.id)).where(and_(
                        TaskCompletionLog.user_id == user.id,
                        TaskCompletionLog.reason == 'task_completed'
                    ))
                
                tasks_completed = await self.db.scalar(tasks_q) or 0
                
                # Ekilgan daraxtlar
                if since:
                    trees_q = select(func.count(Tree.id)).where(and_(
                        Tree.user_id == user.id,
                        Tree.created_at >= since
                    ))
                else:
                    trees_q = select(func.count(Tree.id)).where(Tree.user_id == user.id)
                
                trees_planted = await self.db.scalar(trees_q) or 0
                
                # Faol daraxtlar
                active_trees = await self.db.scalar(
                    select(func.count(Tree.id)).where(and_(
                        Tree.user_id == user.id,
                        Tree.status == 'active'
                    ))
                ) or 0
                
                # G'amxo'rlik bahosi
                care_score = await self._calculate_care_score(user.id)
                
                # Oxirgi faollik
                last_activity_q = select(func.max(TaskCompletionLog.created_at)).where(
                    TaskCompletionLog.user_id == user.id
                )
                last_activity = await self.db.scalar(last_activity_q)
                
                # Faqat faoliyat bo'lganlarni qo'shish
                if tasks_completed > 0 or trees_planted > 0 or user.total_points > 0:
                    leaderboard.append({
                        "user_id": user.id,
                        "full_name": user.full_name,
                        "avatar_url": user.avatar_url,
                        "total_points": user.total_points,
                        "tasks_completed": tasks_completed,
                        "trees_planted": trees_planted,
                        "active_trees": active_trees,
                        "care_score": care_score,
                        "last_activity": last_activity.isoformat() if last_activity else None
                    })
            except Exception as e:
                print(f"Error processing user {user.id}: {e}")
                continue
        
        # Saralash: avval ball, keyin vazifalar
        leaderboard.sort(key=lambda x: (x['total_points'], x['tasks_completed']), reverse=True)
        
        # Rank qo'shish
        for rank, item in enumerate(leaderboard, 1):
            item['rank'] = rank
        
        return leaderboard[:limit]
    
    async def _calculate_care_score(self, user_id: str) -> float:
        """
        G'amxo'rlik bahosi (0-100)
        """
        try:
            # Faol daraxtlar
            trees_q = select(Tree).where(and_(
                Tree.user_id == user_id,
                Tree.status == 'active'
            ))
            trees_r = await self.db.execute(trees_q)
            trees = trees_r.scalars().all()
            
            if not trees:
                return 0.0
            
            total_score = 0
            valid_trees = 0
            
            for tree in trees:
                try:
                    # Yosh
                    age_days = (datetime.utcnow() - tree.created_at).days
                    if age_days == 0:
                        continue
                    
                    # Bajarilgan vazifalar
                    completed = await self.db.scalar(
                        select(func.count(Task.id)).where(and_(
                            Task.tree_id == tree.id,
                            Task.status == 'completed'
                        ))
                    ) or 0
                    
                    # Kutilgan vazifalar (har 7 kunda 2-3 ta)
                    expected = max(1, (age_days // 7) * 2)
                    score = min(100, (completed / expected) * 100)
                    
                    total_score += score
                    valid_trees += 1
                except:
                    continue
            
            if valid_trees == 0:
                return 50.0
                
            return round(total_score / valid_trees, 1)
        except Exception as e:
            print(f"Error calculating care score: {e}")
            return 50.0
