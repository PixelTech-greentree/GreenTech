"""
Task service with segments support and nearby tasks
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from typing import List, Optional, Tuple
from datetime import datetime, timedelta
from math import radians, sin, cos, sqrt, atan2
import uuid

from models import Task, Tree, User, TaskCompletionLog, CheckIn
from schemas import TaskSchema, NearbyTaskItem, TreeWithTasksItem, TreeDetailResponse


class TaskService:
    
    TASK_DESCRIPTIONS = {
        "watering": "Daraxtni sug'oring va rasmga oling",
        "photo_check": "Daraxt holatini tekshiring",
        "closeup": "Barglarni yaqindan suratga oling",
        "clean_area": "Atrofni tozalang"
    }
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    @staticmethod
    def _calculate_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Haversine formula - distance in km"""
        R = 6371
        lat1_rad, lat2_rad = radians(lat1), radians(lat2)
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        
        a = sin(dlat/2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    
    @staticmethod
    def calculate_centroid(segments: List[List[float]]) -> Tuple[float, float]:
        """
        Calculate centroid from polygon segments
        segments = [[lat1, lon1], [lat2, lon2], ...]
        Returns: (centroid_lat, centroid_lon)
        """
        if not segments:
            return 0.0, 0.0
        
        lats = [seg[0] for seg in segments]
        lons = [seg[1] for seg in segments]
        
        return sum(lats) / len(lats), sum(lons) / len(lons)
    
    def get_season(self, date: datetime) -> str:
        month = date.month
        if month in [3, 4, 5]:
            return "spring"
        elif month in [6, 7, 8]:
            return "summer"
        elif month in [9, 10, 11]:
            return "autumn"
        else:
            return "winter"
    
    def calculate_watering_days(self, phase: str, season: str, moisture: str) -> int:
        base = {"seedling": 1, "young": 3, "mature": 7}.get(phase, 3)
        season_mod = {"spring": -1, "summer": -1, "autumn": 1, "winter": 7}.get(season, 0)
        moisture_mod = {"dry": -base, "normal": 0, "wet": 2}.get(moisture, 0)
        
        total = base + season_mod + moisture_mod
        return max(0, min(total, 14))
    
    async def generate_initial_tasks(self, tree: Tree, now: datetime) -> List[Task]:
        """Generate tasks after planting"""
        season = self.get_season(now)
        
        tasks = []
        
        # Watering
        watering_days = self.calculate_watering_days("seedling", season, "normal")
        tasks.append(Task(
            id=str(uuid.uuid4()),
            tree_id=tree.id,
            created_by_user_id=tree.user_id,
            type="watering",
            status="pending",
            created_at=now,
            due_date=now + timedelta(days=watering_days),
            reward_points=30,
            description=self.TASK_DESCRIPTIONS["watering"]
        ))
        
        # Photo check
        tasks.append(Task(
            id=str(uuid.uuid4()),
            tree_id=tree.id,
            created_by_user_id=tree.user_id,
            type="photo_check",
            status="pending",
            created_at=now,
            due_date=now + timedelta(days=2),
            reward_points=20,
            description=self.TASK_DESCRIPTIONS["photo_check"]
        ))
        
        return tasks
    
    async def generate_next_tasks(
        self,
        tree: Tree,
        ai_health: str,
        ai_soil_moisture: str,
        now: datetime
    ) -> List[Task]:
        """Generate next tasks based on condition"""
        season = self.get_season(now)
        age_days = (now - tree.created_at).days
        
        if age_days <= 14:
            phase = "seedling"
        elif age_days <= 90:
            phase = "young"
        else:
            phase = "mature"
        
        tasks = []
        
        # Watering
        watering_days = self.calculate_watering_days(phase, season, ai_soil_moisture)
        tasks.append(Task(
            id=str(uuid.uuid4()),
            tree_id=tree.id,
            created_by_user_id=tree.user_id,
            type="watering",
            status="pending",
            created_at=now,
            due_date=now + timedelta(days=watering_days),
            reward_points=30,
            description=self.TASK_DESCRIPTIONS["watering"]
        ))
        
        # Photo check
        check_days = 2 if phase == "seedling" else 5 if phase == "young" else 10
        if ai_health == "critical":
            check_days = 1
        
        tasks.append(Task(
            id=str(uuid.uuid4()),
            tree_id=tree.id,
            created_by_user_id=tree.user_id,
            type="photo_check",
            status="pending",
            created_at=now,
            due_date=now + timedelta(days=check_days),
            reward_points=20,
            description=self.TASK_DESCRIPTIONS["photo_check"]
        ))
        
        return tasks
    
    # ========================================================================
    # NEARBY TASKS (PUBLIC)
    # ========================================================================
    
    async def release_expired_reservations(self) -> None:
        """Release tasks claimed > 30 min ago"""
        now = datetime.utcnow()
        thirty_min_ago = now - timedelta(minutes=30)
        
        query = select(Task, User).join(User, Task.assigned_user_id == User.id).where(
            and_(
                Task.status == 'claimed',
                Task.claimed_at < thirty_min_ago
            )
        )
        
        result = await self.db.execute(query)
        expired = result.all()
        
        for task, user in expired:
            # Penalty
            user.total_points -= 30
            
            # Log
            log = TaskCompletionLog(
                id=str(uuid.uuid4()),
                user_id=user.id,
                task_id=task.id,
                delta_points=-30,
                reason="reservation_timeout"
            )
            self.db.add(log)
            
            # Release
            task.status = "pending"
            task.assigned_user_id = None
            task.claimed_at = None
        
        if expired:
            await self.db.commit()
    
    async def get_nearby_tasks(
        self,
        user_id: str,
        latitude: float,
        longitude: float
    ) -> List[NearbyTaskItem]:
        """
        Get public tasks within 2km, due today or next 2 days
        """
        now = datetime.utcnow()
        two_days_later = now + timedelta(days=2)
        
        # Get all pending tasks
        query = (
            select(Task, Tree, User)
            .join(Tree, Task.tree_id == Tree.id)
            .join(User, Tree.user_id == User.id)
            .where(and_(
                Task.status == 'pending',
                Task.assigned_user_id == None,
                Task.due_date <= two_days_later,
                Tree.status == 'active'
            ))
        )
        
        result = await self.db.execute(query)
        rows = result.all()
        
        # Filter by distance
        nearby = []
        for task, tree, owner in rows:
            # Use centroid if available, else original coords
            tree_lat = tree.centroid_lat if tree.centroid_lat else tree.latitude
            tree_lon = tree.centroid_lon if tree.centroid_lon else tree.longitude
            
            dist_km = self._calculate_distance_km(latitude, longitude, tree_lat, tree_lon)
            
            if dist_km <= 2.0:
                nearby.append(NearbyTaskItem(
                    task_id=task.id,
                    tree_id=task.tree_id,
                    tree_owner_id=task.created_by_user_id,
                    tree_latitude=tree_lat,
                    tree_longitude=tree_lon,
                    type=task.type,
                    status=task.status,
                    due_date=task.due_date,
                    distance_meters=dist_km * 1000,
                    reward_points=task.reward_points,
                    penalty_points=task.penalty_points,
                    assigned_user_id=None,
                    claimed_at=None,
                    is_my_tree=(task.created_by_user_id == user_id)
                ))
        
        # Sort by distance
        nearby.sort(key=lambda x: x.distance_meters)
        return nearby
    
    async def claim_task(
        self,
        user_id: str,
        task_id: str
    ) -> Tuple[bool, str, Optional[TaskSchema]]:
        """Claim a public task"""
        query = select(Task).where(Task.id == task_id)
        result = await self.db.execute(query)
        task = result.scalar_one_or_none()
        
        if not task:
            return False, "Vazifa topilmadi", None
        
        if task.status != "pending":
            return False, f"Vazifa {task.status} holatida, olib bo'lmaydi", None
        
        if task.assigned_user_id:
            return False, "Bu vazifa allaqachon olingan", None
        
        # Claim
        task.status = "claimed"
        task.assigned_user_id = user_id
        task.claimed_at = datetime.utcnow()
        
        await self.db.commit()
        await self.db.refresh(task)
        
        return True, "Vazifa olindi! 30 daqiqa ichida bajaring.", TaskSchema.from_orm(task)
    
    # ========================================================================
    # MY TREES
    # ========================================================================
    
    async def get_user_trees_with_tasks(self, user_id: str) -> List[TreeWithTasksItem]:
        """Get user's trees with tasks"""
        query = select(Tree).where(Tree.user_id == user_id).order_by(Tree.created_at.desc())
        result = await self.db.execute(query)
        trees = result.scalars().all()
        
        items = []
        for tree in trees:
            # Pending tasks
            pending_q = select(Task).where(and_(
                Task.tree_id == tree.id,
                Task.status == 'pending'
            )).order_by(Task.due_date)
            pending_r = await self.db.execute(pending_q)
            pending = [TaskSchema.from_orm(t) for t in pending_r.scalars().all()]
            
            # Completed tasks
            completed_q = select(Task).where(and_(
                Task.tree_id == tree.id,
                Task.status == 'completed'
            )).order_by(Task.completed_at.desc()).limit(10)
            completed_r = await self.db.execute(completed_q)
            completed = [TaskSchema.from_orm(t) for t in completed_r.scalars().all()]
            
            items.append(TreeWithTasksItem(
                id=tree.id,
                latitude=tree.latitude,
                longitude=tree.longitude,
                centroid_lat=tree.centroid_lat,
                centroid_lon=tree.centroid_lon,
                segments=tree.segments,
                phase=tree.phase,
                status=tree.status,
                last_health=tree.last_health,
                last_soil_moisture=tree.last_soil_moisture,
                created_at=tree.created_at,
                pending_tasks=pending,
                completed_tasks=completed
            ))
        
        return items
    
    async def get_tree_detail(self, tree_id: str) -> Optional[TreeDetailResponse]:
        """Get tree detail"""
        query = select(Tree).where(Tree.id == tree_id)
        result = await self.db.execute(query)
        tree = result.scalar_one_or_none()
        
        if not tree:
            return None
        
        # Tasks
        pending_q = select(Task).where(and_(Task.tree_id == tree_id, Task.status == 'pending'))
        pending_r = await self.db.execute(pending_q)
        pending = [TaskSchema.from_orm(t) for t in pending_r.scalars().all()]
        
        completed_q = select(Task).where(and_(Task.tree_id == tree_id, Task.status == 'completed')).limit(10)
        completed_r = await self.db.execute(completed_q)
        completed = [TaskSchema.from_orm(t) for t in completed_r.scalars().all()]
        
        # Checkins count
        count_q = select(func.count(CheckIn.id)).where(CheckIn.tree_id == tree_id)
        total_checkins = await self.db.scalar(count_q) or 0
        
        # Last checkin
        last_q = select(CheckIn).where(CheckIn.tree_id == tree_id).order_by(CheckIn.timestamp.desc())
        last_r = await self.db.execute(last_q)
        last_checkin = last_r.scalars().first()
        
        return TreeDetailResponse(
            tree=TreeWithTasksItem(
                id=tree.id,
                latitude=tree.latitude,
                longitude=tree.longitude,
                centroid_lat=tree.centroid_lat,
                centroid_lon=tree.centroid_lon,
                segments=tree.segments,
                phase=tree.phase,
                status=tree.status,
                last_health=tree.last_health,
                last_soil_moisture=tree.last_soil_moisture,
                created_at=tree.created_at,
                pending_tasks=pending,
                completed_tasks=completed
            ),
            last_checkin={"timestamp": last_checkin.timestamp.isoformat()} if last_checkin else None,
            total_checkins=total_checkins
        )
