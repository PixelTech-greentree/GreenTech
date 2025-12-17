"""
Tree Health Service - Daraxt salomatligi va batafsil ma'lumotlar
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func, desc
from typing import List, Optional, Dict
from datetime import datetime, timedelta

from models import Tree, CheckIn, Task, User
from services.ai_service import AIService


class TreeHealthService:
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self.ai_service = AIService()
    
    async def get_tree_health_status(self, tree_id: str) -> Optional[Dict]:
        """
        Daraxt salomatlik holati
        """
        # Daraxtni olish
        tree_q = select(Tree).where(Tree.id == tree_id)
        tree_r = await self.db.execute(tree_q)
        tree = tree_r.scalar_one_or_none()
        
        if not tree:
            return None
        
        # Oxirgi tekshiruv
        last_checkin_q = select(CheckIn).where(and_(
            CheckIn.tree_id == tree_id,
            CheckIn.accepted == True
        )).order_by(desc(CheckIn.timestamp))
        last_checkin_r = await self.db.execute(last_checkin_q)
        last_checkin = last_checkin_r.scalars().first()
        
        # Yosh (kunlarda)
        days_old = (datetime.utcnow() - tree.created_at).days
        
        # Salomatlik tendentsiyasi
        health_trend = await self._calculate_health_trend(tree_id)
        
        # Oxirgi AI tahlili
        last_ai_analysis = None
        if last_checkin and last_checkin.ai_raw_response:
            ai_data = last_checkin.ai_raw_response
            if isinstance(ai_data, dict):
                last_ai_analysis = {
                    "health": ai_data.get("health", "unknown"),
                    "moisture": ai_data.get("soil_moisture", "unknown"),
                    "maturity": ai_data.get("maturity", "unknown"),
                    "detailed_analysis": ai_data.get("detailed_analysis", {}),
                    "recommendations": ai_data.get("recommendations", {}),
                    "comment": ai_data.get("comment", "")
                }
        
        # Status aniqlash
        if tree.last_health in ["critical", "dying"]:
            status = "critical"
        elif tree.last_health == "stressed":
            status = "needs_attention"
        else:
            status = "active"
        
        return {
            "tree_id": tree_id,
            "current_health": tree.last_health or "unknown",
            "current_moisture": tree.last_soil_moisture or "unknown",
            "last_check_date": last_checkin.timestamp if last_checkin else None,
            "days_since_planting": days_old,
            "maturity_level": tree.phase,
            "status": status,
            "health_trend": health_trend,
            "last_ai_analysis": last_ai_analysis
        }
    
    async def get_health_history(self, tree_id: str, limit: int = 20) -> List[Dict]:
        """
        Salomatlik tarixi
        """
        query = select(CheckIn).where(and_(
            CheckIn.tree_id == tree_id,
            CheckIn.accepted == True
        )).order_by(desc(CheckIn.timestamp)).limit(limit)
        
        result = await self.db.execute(query)
        checkins = result.scalars().all()
        
        history = []
        for checkin in checkins:
            history.append({
                "date": checkin.timestamp,
                "health": checkin.ai_health or "unknown",
                "moisture": checkin.ai_soil_moisture or "unknown",
                "photo_url": checkin.image_path,
                "ai_comment": checkin.ai_comment or "Ma'lumot yo'q"
            })
        
        return history
    
    async def get_full_tree_details(self, tree_id: str) -> Optional[Dict]:
        """
        Daraxt to'liq tafsilotlari
        """
        # Daraxt
        tree_q = select(Tree).where(Tree.id == tree_id)
        tree_r = await self.db.execute(tree_q)
        tree = tree_r.scalar_one_or_none()
        
        if not tree:
            return None
        
        # Birinchi va oxirgi rasm
        first_checkin_q = select(CheckIn).where(
            CheckIn.tree_id == tree_id
        ).order_by(CheckIn.timestamp)
        first_checkin_r = await self.db.execute(first_checkin_q)
        first_checkin = first_checkin_r.scalars().first()
        
        last_checkin_q = select(CheckIn).where(and_(
            CheckIn.tree_id == tree_id,
            CheckIn.accepted == True
        )).order_by(desc(CheckIn.timestamp))
        last_checkin_r = await self.db.execute(last_checkin_q)
        last_checkin = last_checkin_r.scalars().first()
        
        # Active tasks
        active_tasks_q = select(Task).where(and_(
            Task.tree_id == tree_id,
            Task.status.in_(['pending', 'claimed'])
        )).order_by(Task.due_date)
        active_tasks_r = await self.db.execute(active_tasks_q)
        active_tasks = active_tasks_r.scalars().all()
        
        # Completed tasks count
        completed_count = await self.db.scalar(
            select(func.count(Task.id)).where(and_(
                Task.tree_id == tree_id,
                Task.status == 'completed'
            ))
        ) or 0
        
        # Statistics
        total_waterings = await self.db.scalar(
            select(func.count(CheckIn.id)).where(and_(
                CheckIn.tree_id == tree_id,
                CheckIn.type == 'watering',
                CheckIn.accepted == True
            ))
        ) or 0
        
        total_photos = await self.db.scalar(
            select(func.count(CheckIn.id)).where(
                CheckIn.tree_id == tree_id
            )
        ) or 0
        
        # Yosh
        days_old = (datetime.utcnow() - tree.created_at).days
        
        # Oxirgi AI tahlili
        last_ai_analysis = None
        if last_checkin and last_checkin.ai_raw_response:
            ai_data = last_checkin.ai_raw_response
            if isinstance(ai_data, dict):
                last_ai_analysis = ai_data
        
        # Health trend
        health_trend = await self._calculate_health_trend(tree_id)
        
        # Care score (0-100)
        care_score = await self._calculate_care_score(
            tree_id, days_old, total_waterings, completed_count
        )
        
        # Format active tasks
        formatted_tasks = []
        for task in active_tasks:
            time_remaining = self._format_time_remaining(task.due_date)
            formatted_tasks.append({
                "type": task.type,
                "due_date": task.due_date.strftime("%d %B, %Y %H:%M"),
                "due_date_iso": task.due_date,
                "description": task.description or "",
                "points": task.reward_points,
                "priority": self._get_task_priority(task.due_date),
                "status": task.status,
                "time_remaining": time_remaining,
                "source": "greenify_ai"
            })
        
        return {
            "tree_id": tree_id,
            "user_id": tree.user_id,
            "planted_date": tree.created_at,
            "planted_date_formatted": tree.created_at.strftime("%d %B, %Y"),
            "days_old": days_old,
            
            "latitude": tree.latitude,
            "longitude": tree.longitude,
            "centroid_lat": tree.centroid_lat,
            "centroid_lon": tree.centroid_lon,
            "segments": tree.segments or [],
            
            "phase": tree.phase,
            "status": tree.status,
            "maturity": tree.phase,
            "current_health": tree.last_health or "unknown",
            "current_moisture": tree.last_soil_moisture or "unknown",
            "health_trend": health_trend,
            
            "first_photo_url": first_checkin.image_path if first_checkin else None,
            "latest_photo_url": last_checkin.image_path if last_checkin else None,
            "total_photos": total_photos,
            
            "last_ai_analysis": last_ai_analysis,
            "last_analysis_date": last_checkin.timestamp if last_checkin else None,
            
            "active_tasks": formatted_tasks,
            "completed_tasks_count": completed_count,
            "pending_tasks_count": len([t for t in active_tasks if t.status == 'pending']),
            
            "total_waterings": total_waterings,
            "total_checks": total_photos,
            "care_score": care_score
        }
    
    async def get_user_trees_detailed(
        self, user_id: str, include_completed: bool = False
    ) -> List[Dict]:
        """
        Foydalanuvchi daraxtlari (batafsil)
        """
        query = select(Tree).where(
            Tree.user_id == user_id
        ).order_by(desc(Tree.created_at))
        
        result = await self.db.execute(query)
        trees = result.scalars().all()
        
        detailed_trees = []
        for tree in trees:
            detail = await self.get_full_tree_details(tree.id)
            if detail:
                detailed_trees.append(detail)
        
        return detailed_trees
    
    async def _calculate_health_trend(self, tree_id: str) -> str:
        """
        Salomatlik tendentsiyasini aniqlash
        """
        # Oxirgi 3 ta tekshiruv
        query = select(CheckIn).where(and_(
            CheckIn.tree_id == tree_id,
            CheckIn.accepted == True,
            CheckIn.ai_health.isnot(None)
        )).order_by(desc(CheckIn.timestamp)).limit(3)
        
        result = await self.db.execute(query)
        recent_checkins = result.scalars().all()
        
        if len(recent_checkins) < 2:
            return "unknown"
        
        health_scores = {
            "excellent": 5,
            "healthy": 4,
            "stressed": 3,
            "critical": 2,
            "dying": 1,
            "unknown": 0
        }
        
        scores = [health_scores.get(c.ai_health, 0) for c in recent_checkins]
        
        if scores[0] > scores[-1]:
            return "improving"
        elif scores[0] < scores[-1]:
            return "declining"
        else:
            return "stable"
    
    async def _calculate_care_score(
        self, tree_id: str, days_old: int, waterings: int, completed_tasks: int
    ) -> int:
        """
        G'amxo'rlik bahosi (0-100)
        """
        if days_old == 0:
            return 50
        
        # Kutilgan sug'orishlar
        expected_waterings = days_old // 3  # Har 3 kunda 1 marta
        watering_score = min(100, (waterings / max(1, expected_waterings)) * 50)
        
        # Kutilgan tasklar
        expected_tasks = days_old // 7  # Har haftada 2-3 ta
        task_score = min(100, (completed_tasks / max(1, expected_tasks)) * 50)
        
        total_score = int((watering_score + task_score) / 2)
        return max(0, min(100, total_score))
    
    def _format_time_remaining(self, due_date: datetime) -> str:
        """
        Qolgan vaqtni formatlash
        """
        now = datetime.utcnow()
        delta = due_date - now
        
        if delta.total_seconds() < 0:
            return "Muddati o'tgan"
        elif delta.days > 0:
            return f"{delta.days} kun"
        elif delta.seconds >= 3600:
            hours = delta.seconds // 3600
            return f"{hours} soat"
        else:
            minutes = delta.seconds // 60
            return f"{minutes} daqiqa"
    
    def _get_task_priority(self, due_date: datetime) -> str:
        """
        Vazifa prioritetini aniqlash
        """
        now = datetime.utcnow()
        delta = due_date - now
        
        if delta.total_seconds() < 0:
            return "overdue"
        elif delta.total_seconds() < 3600:  # 1 soat
            return "urgent"
        elif delta.days == 0:  # Bugun
            return "high"
        elif delta.days <= 1:  # Ertaga
            return "medium"
        else:
            return "low"
