"""
Enhanced Task Service - AI-driven task management with image validation
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from fastapi import UploadFile
import uuid

from models import Task, Tree, User, CheckIn, TaskCompletionLog
from services.ai_service import AIService
from services.checkin_service import CheckInService


class EnhancedTaskService:
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self.ai_service = AIService()
        self.checkin_service = CheckInService(db)
    
    async def get_nearby_tasks_enhanced(
        self,
        user_id: str,
        latitude: float,
        longitude: float,
        radius_km: float = 2.0
    ) -> List[Dict]:
        """
        Yaqin atrofdagi vazifalar (kengaytirilgan)
        Faqat vaqti kelgan yoki yaqinlashgan vazifalar
        """
        now = datetime.utcnow()
        
        # Faqat 24 soat ichidagi vazifalar
        time_window = now + timedelta(hours=24)
        
        # Barcha pending va claimed vazifalar
        query = (
            select(Task, Tree, User)
            .join(Tree, Task.tree_id == Tree.id)
            .join(User, Tree.user_id == User.id)
            .where(and_(
                Task.status.in_(['pending', 'claimed']),
                Task.due_date <= time_window,
                Tree.status == 'active'
            ))
        )
        
        result = await self.db.execute(query)
        rows = result.all()
        
        # Masofani filtr qilish
        nearby_tasks = []
        for task, tree, owner in rows:
            tree_lat = tree.centroid_lat if tree.centroid_lat else tree.latitude
            tree_lon = tree.centroid_lon if tree.centroid_lon else tree.longitude
            
            distance = self._calculate_distance(latitude, longitude, tree_lat, tree_lon)
            
            if distance <= radius_km * 1000:  # metrga
                # Foydalanuvchi o'z daraxtimi?
                is_own = (tree.user_id == user_id)
                
                # Band qilish imkoniyati
                can_claim = (
                    task.status == 'pending' and
                    task.due_date <= now + timedelta(hours=24)
                )
                
                # Vaqt formati
                due_date_formatted = self._format_due_date(task.due_date)
                time_remaining = self._format_time_remaining(task.due_date)
                distance_formatted = self._format_distance(distance)
                
                # Urgentlik
                is_urgent = (task.due_date - now).total_seconds() < 3600
                
                nearby_tasks.append({
                    "task_id": task.id,
                    "tree_id": task.tree_id,
                    "tree_owner_name": owner.full_name,
                    "is_own_tree": is_own,
                    "task_type": task.type,
                    "task_description": task.description or self._get_task_description(task.type),
                    "priority": self._get_priority(task.due_date),
                    "due_date": task.due_date,
                    "due_date_formatted": due_date_formatted,
                    "time_remaining": time_remaining,
                    "is_urgent": is_urgent,
                    
                    "tree_latitude": tree_lat,
                    "tree_longitude": tree_lon,
                    "distance_meters": round(distance, 2),
                    "distance_formatted": distance_formatted,
                    
                    "points_reward": task.reward_points,
                    "current_status": task.status,
                    "can_claim": can_claim,
                    "claimed_by": task.assigned_user_id,
                    "claim_expires_at": task.claimed_at + timedelta(minutes=30) if task.claimed_at else None,
                    
                    "tree_health": tree.last_health or "unknown",
                    "tree_maturity": tree.phase,
                    "requires_photo": True
                })
        
        # Masofa bo'yicha saralash
        nearby_tasks.sort(key=lambda x: x['distance_meters'])
        
        return nearby_tasks
    
    async def claim_task_enhanced(self, task_id: str, user_id: str) -> Dict:
        """
        Vazifani band qilish (kengaytirilgan tekshirish bilan)
        """
        # Vazifani olish
        task_q = select(Task).where(Task.id == task_id)
        task_r = await self.db.execute(task_q)
        task = task_r.scalar_one_or_none()
        
        if not task:
            return {"success": False, "message": "Vazifa topilmadi"}
        
        # Vaqt tekshiruvi
        now = datetime.utcnow()
        if task.due_date > now + timedelta(hours=24):
            time_until = self._format_time_remaining(task.due_date - timedelta(hours=24))
            return {
                "success": False,
                "message": f"Vazifani band qilish uchun yana {time_until} kutish kerak"
            }
        
        # Status tekshiruvi
        if task.status != 'pending':
            if task.status == 'claimed' and task.assigned_user_id == user_id:
                return {
                    "success": False,
                    "message": "Siz bu vazifani allaqachon band qilgansiz"
                }
            else:
                return {
                    "success": False,
                    "message": "Bu vazifa allaqachon band qilingan yoki tugallangan"
                }
        
        # Band qilish
        task.status = 'claimed'
        task.assigned_user_id = user_id
        task.claimed_at = now
        
        await self.db.commit()
        await self.db.refresh(task)
        
        expires_at = now + timedelta(minutes=30)
        
        return {
            "success": True,
            "message": "Vazifa band qilindi! 30 daqiqa ichida rasmga olib yuboring.",
            "task_id": task_id,
            "expires_at": expires_at.isoformat(),
            "time_remaining": "30 daqiqa"
        }
    
    async def complete_task_with_validation(
        self,
        task_id: str,
        user_id: str,
        latitude: float,
        longitude: float,
        client_timestamp: str,
        image_file: UploadFile
    ) -> Dict:
        """
        Vazifani rasm bilan bajarish va AI validatsiya
        """
        # Vazifani olish
        task_q = select(Task, Tree).join(Tree, Task.tree_id == Tree.id).where(Task.id == task_id)
        task_r = await self.db.execute(task_q)
        row = task_r.first()
        
        if not row:
            raise ValueError("Vazifa topilmadi")
        
        task, tree = row
        
        # Tekshiruvlar
        if task.status == 'completed':
            raise ValueError("Bu vazifa allaqachon bajarilgan")
        
        if task.status == 'claimed' and task.assigned_user_id != user_id:
            raise ValueError("Bu vazifa boshqa foydalanuvchi tomonidan band qilingan")
        
        # Vaqt tekshiruvi
        now = datetime.utcnow()
        if task.status == 'claimed' and task.claimed_at:
            if now > task.claimed_at + timedelta(minutes=30):
                # Jarima
                user = await self._get_user(user_id)
                user.total_points -= 30
                
                log = TaskCompletionLog(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    task_id=task_id,
                    delta_points=-30,
                    reason="claim_timeout"
                )
                self.db.add(log)
                
                task.status = 'pending'
                task.assigned_user_id = None
                task.claimed_at = None
                
                await self.db.commit()
                
                return {
                    "success": False,
                    "message": "30 daqiqa muddati o'tdi. -30 ball jarima.",
                    "task_id": task_id,
                    "points_earned": -30,
                    "total_points": user.total_points
                }
        
        # CheckIn service orqali rasm tahlili
        try:
            checkin_result = await self.checkin_service.process_checkin(
                user_id=user_id,
                tree_id=tree.id,
                task_id=task_id,
                latitude=latitude,
                longitude=longitude,
                client_timestamp=client_timestamp,
                phase_hint=task.type,
                image_file=image_file
            )
            
            if not checkin_result.accepted:
                return {
                    "success": False,
                    "message": checkin_result.message,
                    "task_id": task_id,
                    "points_earned": 0,
                    "total_points": checkin_result.points.total,
                    "ai_feedback": checkin_result.analysis
                }
            
            # Muvaffaqiyatli bajarildi
            # Keyingi vazifalar AI dan
            next_tasks = await self._generate_ai_tasks(
                tree=tree,
                last_health=checkin_result.analysis.health if checkin_result.analysis else "unknown",
                last_moisture=checkin_result.analysis.soil_moisture if checkin_result.analysis else "unknown"
            )
            
            return {
                "success": True,
                "message": f"Vazifa muvaffaqiyatli bajarildi! +{checkin_result.points.awarded} ball",
                "task_id": task_id,
                "points_earned": checkin_result.points.awarded,
                "total_points": checkin_result.points.total,
                "ai_feedback": checkin_result.analysis,
                "next_tasks": next_tasks
            }
            
        except Exception as e:
            raise ValueError(f"Rasm tahlil qilishda xatolik: {str(e)}")
    
    async def _generate_ai_tasks(self, tree: Tree, last_health: str, last_moisture: str) -> List[Dict]:
        """
        AI dan keyingi vazifalarni olish
        """
        now = datetime.utcnow()
        age_days = (now - tree.created_at).days
        
        try:
            ai_tasks = await self.ai_service.generate_care_tasks(
                health=last_health,
                soil_moisture=last_moisture,
                maturity=tree.phase,
                age_days=age_days,
                current_date=now
            )
            
            # Database ga saqlash
            saved_tasks = []
            for ai_task in ai_tasks:
                due_date = datetime.fromisoformat(ai_task['due_date'])
                
                task = Task(
                    id=str(uuid.uuid4()),
                    tree_id=tree.id,
                    created_by_user_id=tree.user_id,
                    type=ai_task['type'],
                    status='pending',
                    created_at=now,
                    due_date=due_date,
                    reward_points=ai_task['points'],
                    description=ai_task['description']
                )
                
                self.db.add(task)
                saved_tasks.append({
                    "type": ai_task['type'],
                    "due_date": self._format_due_date(due_date),
                    "due_date_iso": due_date,
                    "description": ai_task['description'],
                    "points": ai_task['points'],
                    "priority": ai_task.get('priority', 'medium'),
                    "status": "pending",
                    "source": "greenify_ai"
                })
            
            await self.db.commit()
            
            return saved_tasks
            
        except Exception as e:
            print(f"AI task generation failed: {e}")
            # Fallback: oddiy tasklar
            return []
    
    # Helper methods
    
    def _calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Masofa (metrda)"""
        from math import radians, sin, cos, sqrt, atan2
        R = 6371000
        lat1_rad, lat2_rad = radians(lat1), radians(lat2)
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        a = sin(dlat/2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    
    def _format_due_date(self, due_date: datetime) -> str:
        """Vaqtni formatlash"""
        now = datetime.utcnow()
        delta = due_date - now
        
        if delta.days < 0:
            return f"Muddati o'tgan"
        elif delta.days == 0:
            return f"Bugun {due_date.strftime('%H:%M')}"
        elif delta.days == 1:
            return f"Ertaga {due_date.strftime('%H:%M')}"
        elif delta.days <= 7:
            return f"{delta.days} kun ichida"
        else:
            return due_date.strftime("%d %B, %Y")
    
    def _format_time_remaining(self, due_date: datetime) -> str:
        """Qolgan vaqt"""
        now = datetime.utcnow()
        delta = due_date - now
        
        if delta.total_seconds() < 0:
            return "Muddati o'tgan"
        elif delta.days > 0:
            return f"{delta.days} kun"
        elif delta.seconds >= 3600:
            hours = delta.seconds // 3600
            minutes = (delta.seconds % 3600) // 60
            return f"{hours} soat {minutes} daqiqa" if minutes > 0 else f"{hours} soat"
        else:
            minutes = delta.seconds // 60
            return f"{minutes} daqiqa"
    
    def _format_distance(self, meters: float) -> str:
        """Masofani formatlash"""
        if meters < 1000:
            return f"{int(meters)} metr"
        else:
            km = meters / 1000
            return f"{km:.1f} km"
    
    def _get_priority(self, due_date: datetime) -> str:
        """Prioritet"""
        now = datetime.utcnow()
        delta = due_date - now
        
        if delta.total_seconds() < 3600:
            return "urgent"
        elif delta.days == 0:
            return "high"
        elif delta.days <= 1:
            return "medium"
        else:
            return "low"
    
    def _get_task_description(self, task_type: str) -> str:
        """Task tavsifi"""
        descriptions = {
            "watering": "Daraxtni yaxshilab sug'oring va tuproq namligini tekshiring",
            "photo_check": "Daraxt holatini tekshiring va rasmga oling",
            "fertilizing": "O'g'itlang va tuproqni boyiting",
            "pruning": "Qurib qolgan barglarni olib tashlang",
            "pest_check": "Zararkunandalar borligini tekshiring",
            "support": "Qiyshaygan bo'lsa tayoqqa bog'lang"
        }
        return descriptions.get(task_type, "Vazifani bajaring")
    
    async def _get_user(self, user_id: str) -> User:
        """User olish"""
        query = select(User).where(User.id == user_id)
        result = await self.db.execute(query)
        return result.scalar_one()
