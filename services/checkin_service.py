"""
Complete check-in processing service
"""
import hashlib
import os
from datetime import datetime, timedelta
from typing import Optional
from pathlib import Path
import uuid
from math import radians, sin, cos, sqrt, atan2

from fastapi import UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from PIL import Image
import imagehash
import io

from models import CheckIn, Tree, Task, User, TaskCompletionLog
from schemas import CheckInAnalysisResponse, AIAnalysis, TaskSchema, PointsSummary
from services.ai_service import AIService
from services.task_service import TaskService


class CheckInService:
    
    MEDIA_DIR = Path("media/checkins")
    DUPLICATE_HASH_THRESHOLD = 5
    MAX_DISTANCE_METERS_OWNER = 5
    MAX_DISTANCE_METERS_PUBLIC = float('inf')  # No limit for public
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self.ai_service = AIService()
        self.task_service = TaskService(db)
        self.MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    
    async def process_checkin(
        self,
        user_id: str,
        tree_id: Optional[str],
        task_id: Optional[str],
        latitude: float,
        longitude: float,
        client_timestamp: str,
        phase_hint: Optional[str],
        image_file: UploadFile
    ) -> CheckInAnalysisResponse:
        """Main check-in processing"""
        current_date = datetime.utcnow()
        
        # Save and hash image
        image_path, file_hash, perceptual_hash, image_bytes = await self._save_and_hash_image(image_file)
        
        # NEW PLANTING
        if tree_id is None:
            return await self._process_new_planting(
                user_id, latitude, longitude, client_timestamp,
                image_path, file_hash, perceptual_hash, image_bytes, current_date
            )
        
        # EXISTING TREE
        return await self._process_existing_tree(
            user_id, tree_id, task_id, latitude, longitude, client_timestamp,
            phase_hint, image_path, file_hash, perceptual_hash, image_bytes, current_date
        )
    
    async def _save_and_hash_image(self, image_file: UploadFile):
        """Save image and compute hashes"""
        image_bytes = await image_file.read()
        
        # File hash
        file_hash = hashlib.md5(image_bytes).hexdigest()
        
        # Perceptual hash
        image = Image.open(io.BytesIO(image_bytes))
        p_hash = str(imagehash.phash(image))
        
        # Save
        filename = f"{uuid.uuid4()}.jpg"
        file_path = self.MEDIA_DIR / filename
        
        with open(file_path, "wb") as f:
            f.write(image_bytes)
        
        return str(file_path), file_hash, p_hash, image_bytes
    
    def _calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Distance in meters"""
        R = 6371000
        lat1_rad = radians(lat1)
        lat2_rad = radians(lat2)
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        
        a = sin(dlat/2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return R * c
    
    async def _process_new_planting(
        self,
        user_id: str,
        latitude: float,
        longitude: float,
        client_timestamp: str,
        image_path: str,
        file_hash: str,
        perceptual_hash: str,
        image_bytes: bytes,
        current_date: datetime
    ) -> CheckInAnalysisResponse:
        """Process new tree planting"""
        
        # Check duplicates
        recent_q = select(CheckIn).where(and_(
            CheckIn.user_id == user_id,
            CheckIn.timestamp >= current_date - timedelta(hours=1)
        ))
        recent_r = await self.db.execute(recent_q)
        recent_checkins = recent_r.scalars().all()
        
        for checkin in recent_checkins:
            if checkin.image_hash == file_hash:
                user = await self._get_user(user_id)
                return CheckInAnalysisResponse(
                    status="ANALYZED",
                    accepted=False,
                    cheat_suspected=True,
                    error_code="EXACT_DUPLICATE",
                    message="Bu rasm avval yuklangan",
                    points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
                )
        
        # AI Analysis
        ai_result = await self.ai_service.analyze_single_image(image_bytes)
        
        # STRICT VALIDATION
        rejection_reason = None
        rejection_code = None
        error_messages = {
            "NOT_TREE": "Bu daraxt emas. Iltimos, haqiqiy daraxt rasmini yuklang.",
            "FAKE_PHOTO": "Bu haqiqiy surat emas. Iltimos, jonli rasm oling.",
            "NOT_SEEDLING": "Faqat yosh ko'chatlar qabul qilinadi.",
            "TOO_BIG_TREE": "Bu daraxt juda katta. Biz faqat yangi ko'chatlarni qabul qilamiz."
        }
        
        if not ai_result["is_tree"]:
            rejection_code = "NOT_TREE"
        elif not ai_result["is_real_photo"]:
            rejection_code = "FAKE_PHOTO"
        elif not ai_result["is_seedling"]:
            rejection_code = "NOT_SEEDLING"
        elif ai_result["maturity"] == "mature":
            rejection_code = "TOO_BIG_TREE"
        
        if rejection_code:
            # Save rejected checkin
            checkin = CheckIn(
                user_id=user_id,
                image_path=image_path,
                image_hash=file_hash,
                perceptual_hash=perceptual_hash,
                latitude=latitude,
                longitude=longitude,
                client_timestamp=client_timestamp,
                type="planting",
                ai_raw_response=ai_result,
                ai_tree=ai_result["is_tree"],
                ai_real_photo=ai_result["is_real_photo"],
                ai_seedling=ai_result["is_seedling"],
                ai_maturity=ai_result["maturity"],
                ai_health=ai_result["health"],
                ai_soil_moisture=ai_result["soil_moisture"],
                accepted=False,
                rejected_reason=rejection_code
            )
            self.db.add(checkin)
            await self.db.commit()
            
            user = await self._get_user(user_id)
            
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                error_code=rejection_code,
                message=error_messages.get(rejection_code, "Rad etildi"),
                analysis=AIAnalysis(**ai_result),
                points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
            )
        
        # ACCEPTED - Create tree
        tree = Tree(
            id=str(uuid.uuid4()),
            user_id=user_id,
            latitude=latitude,
            longitude=longitude,
            phase="seedling",
            status="active",
            last_health=ai_result["health"],
            last_soil_moisture=ai_result["soil_moisture"],
            last_analysis_at=current_date,
            initial_bonus_awarded=False
        )
        self.db.add(tree)
        
        # Save checkin
        checkin = CheckIn(
            user_id=user_id,
            tree_id=tree.id,
            image_path=image_path,
            image_hash=file_hash,
            perceptual_hash=perceptual_hash,
            latitude=latitude,
            longitude=longitude,
            client_timestamp=client_timestamp,
            type="planting",
            ai_raw_response=ai_result,
            ai_tree=ai_result["is_tree"],
            ai_real_photo=ai_result["is_real_photo"],
            ai_seedling=ai_result["is_seedling"],
            ai_maturity=ai_result["maturity"],
            ai_health=ai_result["health"],
            ai_soil_moisture=ai_result["soil_moisture"],
            ai_comment=ai_result["comment"],
            accepted=True
        )
        self.db.add(checkin)
        
        # Generate initial tasks
        initial_tasks = await self.task_service.generate_initial_tasks(tree, current_date)
        for task in initial_tasks:
            self.db.add(task)
        
        await self.db.commit()
        
        # Refresh
        await self.db.refresh(tree)
        for task in initial_tasks:
            await self.db.refresh(task)
        
        user = await self._get_user(user_id)
        
        return CheckInAnalysisResponse(
            status="ANALYZED",
            accepted=True,
            tree_id=tree.id,
            analysis=AIAnalysis(**ai_result),
            new_tasks=[TaskSchema.from_orm(t) for t in initial_tasks],
            updated_tasks=[],
            points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
        )
    
    async def _process_existing_tree(
        self,
        user_id: str,
        tree_id: str,
        task_id: Optional[str],
        latitude: float,
        longitude: float,
        client_timestamp: str,
        phase_hint: Optional[str],
        image_path: str,
        file_hash: str,
        perceptual_hash: str,
        image_bytes: bytes,
        current_date: datetime
    ) -> CheckInAnalysisResponse:
        """Process check-in for existing tree"""
        
        # Load tree
        tree_q = select(Tree).where(Tree.id == tree_id)
        tree_r = await self.db.execute(tree_q)
        tree = tree_r.scalar_one_or_none()
        
        if not tree:
            raise ValueError("Daraxt topilmadi")
        
        # Check GPS distance
        is_owner = (tree.user_id == user_id)
        max_distance = self.MAX_DISTANCE_METERS_OWNER if is_owner else self.MAX_DISTANCE_METERS_PUBLIC
        
        distance = self._calculate_distance(
            latitude, longitude,
            tree.latitude, tree.longitude
        )
        
        if distance > max_distance:
            user = await self._get_user(user_id)
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                error_code="LOCATION_MISMATCH",
                message=f"Siz daraxtdan {int(distance)}m uzoqdasiz. Yaqinroq boring.",
                tree_id=tree_id,
                points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
            )
        
        # Get previous checkin
        prev_q = select(CheckIn).where(and_(
            CheckIn.tree_id == tree_id,
            CheckIn.accepted == True
        )).order_by(CheckIn.timestamp.desc())
        prev_r = await self.db.execute(prev_q)
        previous_checkin = prev_r.scalars().first()
        
        # Check exact duplicate
        if previous_checkin and previous_checkin.image_hash == file_hash:
            user = await self._get_user(user_id)
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                cheat_suspected=True,
                error_code="EXACT_DUPLICATE",
                message="Bu rasm avval yuklangan",
                tree_id=tree_id,
                points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
            )
        
        # AI Analysis
        if previous_checkin:
            with open(previous_checkin.image_path, 'rb') as f:
                prev_bytes = f.read()
            ai_result = await self.ai_service.compare_images(prev_bytes, image_bytes)
            
            if ai_result.get("same_scene", False):
                user = await self._get_user(user_id)
                return CheckInAnalysisResponse(
                    status="ANALYZED",
                    accepted=False,
                    cheat_suspected=True,
                    error_code="SAME_SCENE",
                    message="Rasm bir xil vaqt va joyda olingan",
                    tree_id=tree_id,
                    points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
                )
        else:
            ai_result = await self.ai_service.analyze_single_image(image_bytes)
        
        # Validate is_tree and is_real_photo
        if not ai_result.get("is_tree", True):
            user = await self._get_user(user_id)
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                error_code="NO_TREE_IN_IMAGE",
                message="Rasmda daraxt ko'rinmayapti",
                tree_id=tree_id,
                analysis=AIAnalysis(**ai_result) if all(k in ai_result for k in ["is_tree", "is_real_photo", "is_seedling", "maturity", "health", "soil_moisture", "comment"]) else None,
                points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
            )
        
        if not ai_result.get("is_real_photo", True):
            user = await self._get_user(user_id)
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                error_code="FAKE_PHOTO",
                message="Bu haqiqiy surat emas",
                tree_id=tree_id,
                analysis=AIAnalysis(**ai_result) if all(k in ai_result for k in ["is_tree", "is_real_photo", "is_seedling", "maturity", "health", "soil_moisture", "comment"]) else None,
                points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
            )
        
        # Handle task completion
        awarded_points = 0
        penalty_points = 0
        completed_task = None
        
        if task_id:
            task_q = select(Task).where(Task.id == task_id)
            task_r = await self.db.execute(task_q)
            task = task_r.scalar_one_or_none()
            
            if not task:
                raise ValueError("Vazifa topilmadi")
            
            # Check if overdue
            if current_date > task.due_date and task.status == "pending":
                task.status = "off"
                task.penalty_points = -35
                
                user = await self._get_user(user_id)
                user.total_points += task.penalty_points
                penalty_points = task.penalty_points
                
                log = TaskCompletionLog(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    task_id=task_id,
                    delta_points=task.penalty_points,
                    reason="task_late_penalty"
                )
                self.db.add(log)
                await self.db.commit()
                
                return CheckInAnalysisResponse(
                    status="ANALYZED",
                    accepted=False,
                    error_code="TASK_LATE",
                    message="Vazifa muddati o'tgan, -35 ball jar imasi",
                    tree_id=tree_id,
                    updated_tasks=[TaskSchema.from_orm(task)],
                    points=PointsSummary(awarded=0, penalty=penalty_points, total=user.total_points)
                )
            
            # Check if reserved by another user
            if task.status == "claimed" and task.assigned_user_id != user_id:
                user = await self._get_user(user_id)
                return CheckInAnalysisResponse(
                    status="ANALYZED",
                    accepted=False,
                    error_code="TASK_RESERVED_BY_OTHER",
                    message="Bu vazifa boshqa foydalanuvchi tomonidan olingan",
                    tree_id=tree_id,
                    points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
                )
            
            # Check reservation timeout
            if task.status == "claimed" and task.assigned_user_id == user_id and task.claimed_at:
                if current_date > task.claimed_at + timedelta(minutes=30):
                    # Apply penalty
                    user = await self._get_user(user_id)
                    user.total_points -= 30
                    penalty_points = -30
                    
                    log = TaskCompletionLog(
                        id=str(uuid.uuid4()),
                        user_id=user_id,
                        task_id=task_id,
                        delta_points=-30,
                        reason="reservation_timeout"
                    )
                    self.db.add(log)
                    
                    task.status = "pending"
                    task.assigned_user_id = None
                    task.claimed_at = None
                    
                    await self.db.commit()
                    
                    return CheckInAnalysisResponse(
                        status="ANALYZED",
                        accepted=False,
                        error_code="RESERVATION_TIMEOUT",
                        message="Vazifa vaqti tugagan, -30 ball jarimasi",
                        tree_id=tree_id,
                        points=PointsSummary(awarded=0, penalty=penalty_points, total=user.total_points)
                    )
            
            # Complete task
            if task.type == "watering":
                if ai_result.get("soil_moisture") == "dry":
                    # Not watered enough
                    checkin = CheckIn(
                        user_id=user_id,
                        tree_id=tree_id,
                        image_path=image_path,
                        image_hash=file_hash,
                        perceptual_hash=perceptual_hash,
                        latitude=latitude,
                        longitude=longitude,
                        client_timestamp=client_timestamp,
                        type="watering",
                        ai_raw_response=ai_result,
                        accepted=False,
                        rejected_reason="LOW_MOISTURE"
                    )
                    self.db.add(checkin)
                    await self.db.commit()
                    
                    user = await self._get_user(user_id)
                    return CheckInAnalysisResponse(
                        status="ANALYZED",
                        accepted=False,
                        error_code="LOW_MOISTURE",
                        message="Tuproq hali ham quruq, qaytadan sug'oring",
                        tree_id=tree_id,
                        analysis=AIAnalysis(**ai_result) if all(k in ai_result for k in ["is_tree", "is_real_photo", "is_seedling", "maturity", "health", "soil_moisture", "comment"]) else None,
                        points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
                    )
                
                # Success
                task.status = "completed"
                task.completed_at = current_date
                awarded_points = task.reward_points
                
                # Check for initial bonus
                if not tree.initial_bonus_awarded:
                    awarded_points += 50
                    tree.initial_bonus_awarded = True
                    
                    bonus_log = TaskCompletionLog(
                        id=str(uuid.uuid4()),
                        user_id=user_id,
                        task_id=task_id,
                        delta_points=50,
                        reason="initial_bonus"
                    )
                    self.db.add(bonus_log)
                
                completed_task = task
            
            elif task.type in ["photo_check", "closeup", "clean_area"]:
                task.status = "completed"
                task.completed_at = current_date
                awarded_points = task.reward_points
                completed_task = task
            
            # Update user points
            if awarded_points > 0:
                user = await self._get_user(user_id)
                user.total_points += awarded_points
                
                log = TaskCompletionLog(
                    id=str(uuid.uuid4()),
                    user_id=user_id,
                    task_id=task_id,
                    delta_points=awarded_points,
                    reason="task_completed"
                )
                self.db.add(log)
        
        # Save checkin
        checkin = CheckIn(
            user_id=user_id,
            tree_id=tree_id,
            image_path=image_path,
            image_hash=file_hash,
            perceptual_hash=perceptual_hash,
            latitude=latitude,
            longitude=longitude,
            client_timestamp=client_timestamp,
            type=phase_hint or "monitoring",
            ai_raw_response=ai_result,
            ai_tree=ai_result.get("is_tree"),
            ai_real_photo=ai_result.get("is_real_photo"),
            ai_seedling=ai_result.get("is_seedling"),
            ai_maturity=ai_result.get("maturity"),
            ai_health=ai_result.get("health"),
            ai_soil_moisture=ai_result.get("soil_moisture"),
            ai_comment=ai_result.get("comment") or ai_result.get("changes"),
            accepted=True
        )
        self.db.add(checkin)
        
        # Update tree
        tree.last_health = ai_result.get("health")
        tree.last_soil_moisture = ai_result.get("soil_moisture")
        tree.last_analysis_at = current_date
        
        # Generate new tasks
        new_tasks = await self.task_service.generate_next_tasks(
            tree,
            ai_result.get("health", "unknown"),
            ai_result.get("soil_moisture", "unknown"),
            current_date
        )
        for new_task in new_tasks:
            self.db.add(new_task)
        
        await self.db.commit()
        
        # Refresh
        for new_task in new_tasks:
            await self.db.refresh(new_task)
        
        user = await self._get_user(user_id)
        
        updated_tasks = [TaskSchema.from_orm(completed_task)] if completed_task else []
        
        return CheckInAnalysisResponse(
            status="ANALYZED",
            accepted=True,
            tree_id=tree_id,
            task_id=task_id,
            analysis=AIAnalysis(**ai_result) if all(k in ai_result for k in ["is_tree", "is_real_photo", "is_seedling", "maturity", "health", "soil_moisture", "comment"]) else None,
            new_tasks=[TaskSchema.from_orm(t) for t in new_tasks],
            updated_tasks=updated_tasks,
            points=PointsSummary(
                awarded=awarded_points,
                penalty=penalty_points,
                total=user.total_points if user else 0
            )
        )
    
    async def _get_user(self, user_id: str) -> Optional[User]:
        query = select(User).where(User.id == user_id)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()
