"""
Task generation engine based on tree phase, season, and conditions
"""
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
import uuid

from models import Task, Tree


class TaskService:
    
    TASK_DESCRIPTIONS = {
        "watering": "Daraxtingizni sug'oring va rasmga oling",
        "photo_check": "Daraxt holatini tekshiring va rasmga oling",
        "closeup_photo": "Daraxt barglarini yaqindan suratga oling",
        "clean_area": "Daraxt atrofini tozalang va rasmga oling",
        "fertilize": "Daraxtga o'g'it qo'shing",
        "check_roots": "Ildiz atrofini tekshiring"
    }
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_season(self, date: datetime) -> str:
        """Determine season based on month"""
        month = date.month
        if month in [3, 4, 5]:
            return "spring"
        elif month in [6, 7, 8]:
            return "summer"
        elif month in [9, 10, 11]:
            return "autumn"
        else:
            return "winter"
    
    def get_tree_phase(self, tree: Tree, current_date: datetime) -> str:
        """
        Determine tree phase based on age:
        - seedling: 0-14 days
        - young: 15-90 days
        - mature: 90+ days
        """
        age_days = (current_date - tree.created_at).days
        
        if age_days <= 14:
            return "seedling"
        elif age_days <= 90:
            return "young"
        else:
            return "mature"
    
    def calculate_next_watering_days(
        self, 
        phase: str, 
        season: str, 
        soil_moisture: str
    ) -> int:
        """
        Calculate days until next watering task.
        
        Base intervals:
        - seedling: 1 day
        - young: 3 days
        - mature: 7 days
        
        Season modifiers:
        - spring: -1 day
        - summer: -1 day
        - autumn: +1 day
        - winter: +7 days
        
        Moisture modifiers:
        - dry: 0 days (immediate)
        - normal: no change
        - wet: +2 days
        """
        # Base interval
        base_days = {
            "seedling": 1,
            "young": 3,
            "mature": 7
        }.get(phase, 3)
        
        # Season modifier
        season_modifier = {
            "spring": -1,
            "summer": -1,
            "autumn": 1,
            "winter": 7
        }.get(season, 0)
        
        # Moisture modifier
        moisture_modifier = {
            "dry": -base_days,  # Make it 0 (immediate)
            "normal": 0,
            "wet": 2
        }.get(soil_moisture, 0)
        
        total_days = base_days + season_modifier + moisture_modifier
        
        # Minimum 0 days, maximum 14 days
        return max(0, min(total_days, 14))
    
    def calculate_next_check_days(
        self, 
        phase: str, 
        season: str, 
        health: str
    ) -> int:
        """
        Calculate days until next photo check task.
        
        Base intervals:
        - seedling: 2 days
        - young: 5 days
        - mature: 10 days
        
        Health modifiers:
        - healthy: no change
        - stressed: -2 days
        - critical: -4 days
        """
        base_days = {
            "seedling": 2,
            "young": 5,
            "mature": 10
        }.get(phase, 5)
        
        health_modifier = {
            "healthy": 0,
            "stressed": -2,
            "critical": -4
        }.get(health, 0)
        
        season_modifier = {
            "winter": 3
        }.get(season, 0)
        
        total_days = base_days + health_modifier + season_modifier
        
        return max(1, min(total_days, 14))
    
    async def generate_initial_tasks(
        self, 
        tree: Tree, 
        current_date: datetime
    ) -> List[Task]:
        """
        Generate initial tasks after first planting.
        
        Creates:
        1. Watering task (1 day)
        2. Photo check task (2 days)
        """
        season = self.get_season(current_date)
        phase = "seedling"
        
        tasks = []
        
        # Watering task
        watering_days = self.calculate_next_watering_days(phase, season, "normal")
        watering_task = Task(
            id=str(uuid.uuid4()),
            tree_id=tree.id,
            user_id=tree.user_id,
            type="watering",
            status="pending",
            created_at=current_date,
            due_date=current_date + timedelta(days=watering_days),
            reward_points=30,
            description=self.TASK_DESCRIPTIONS["watering"]
        )
        tasks.append(watering_task)
        
        # Photo check task
        check_days = self.calculate_next_check_days(phase, season, "healthy")
        check_task = Task(
            id=str(uuid.uuid4()),
            tree_id=tree.id,
            user_id=tree.user_id,
            type="photo_check",
            status="pending",
            created_at=current_date,
            due_date=current_date + timedelta(days=check_days),
            reward_points=20,
            description=self.TASK_DESCRIPTIONS["photo_check"]
        )
        tasks.append(check_task)
        
        return tasks
    
    async def generate_next_tasks(
        self,
        tree: Tree,
        ai_health: str,
        ai_soil_moisture: str,
        current_date: datetime
    ) -> List[Task]:
        """
        Generate next tasks based on tree condition and phase.
        """
        season = self.get_season(current_date)
        phase = self.get_tree_phase(tree, current_date)
        
        tasks = []
        
        # Always generate a watering task
        watering_days = self.calculate_next_watering_days(
            phase, season, ai_soil_moisture
        )
        watering_task = Task(
            id=str(uuid.uuid4()),
            tree_id=tree.id,
            user_id=tree.user_id,
            type="watering",
            status="pending",
            created_at=current_date,
            due_date=current_date + timedelta(days=watering_days),
            reward_points=30,
            description=self.TASK_DESCRIPTIONS["watering"]
        )
        tasks.append(watering_task)
        
        # Generate photo check task
        check_days = self.calculate_next_check_days(phase, season, ai_health)
        check_task = Task(
            id=str(uuid.uuid4()),
            tree_id=tree.id,
            user_id=tree.user_id,
            type="photo_check",
            status="pending",
            created_at=current_date,
            due_date=current_date + timedelta(days=check_days),
            reward_points=20,
            description=self.TASK_DESCRIPTIONS["photo_check"]
        )
        tasks.append(check_task)
        
        # If tree is stressed or critical, add urgent tasks
        if ai_health == "critical":
            urgent_task = Task(
                id=str(uuid.uuid4()),
                tree_id=tree.id,
                user_id=tree.user_id,
                type="closeup_photo",
                status="pending",
                created_at=current_date,
                due_date=current_date + timedelta(days=1),
                reward_points=25,
                description="TEZKOR: Daraxt kasallanishi mumkin, yaqindan rasmga oling"
            )
            tasks.append(urgent_task)
        
        # If soil is very dry, prioritize watering
        if ai_soil_moisture == "dry":
            # Update watering task to be immediate
            watering_task.due_date = current_date
            watering_task.description = "TEZKOR: Tuproq quruq, darhol sug'oring!"
        
        # For mature trees in good health, add maintenance tasks
        if phase == "mature" and ai_health == "healthy":
            clean_task = Task(
                id=str(uuid.uuid4()),
                tree_id=tree.id,
                user_id=tree.user_id,
                type="clean_area",
                status="pending",
                created_at=current_date,
                due_date=current_date + timedelta(days=7),
                reward_points=15,
                description=self.TASK_DESCRIPTIONS["clean_area"]
            )
            tasks.append(clean_task)
        
        return tasks
    
    async def check_and_apply_penalties(
        self,
        user_id: str,
        current_date: datetime
    ) -> List[Task]:
        """
        Check for overdue tasks and apply penalties.
        Returns list of tasks that were marked as OFF with penalties.
        """
        overdue_tasks = self.db.query(Task).filter(
            Task.user_id == user_id,
            Task.status == "pending",
            Task.due_date < current_date
        ).all()
        
        penalized_tasks = []
        for task in overdue_tasks:
            task.status = "off"
            task.penalty_points = -35
            penalized_tasks.append(task)
        
        self.db.commit()
        return penalized_tasks
