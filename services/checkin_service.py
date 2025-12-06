"""
Main check-in processing service with anti-cheat validation
"""
import hashlib
import os
from datetime import datetime
from typing import Optional
from pathlib import Path
import uuid
from math import radians, sin, cos, sqrt, atan2

from fastapi import UploadFile
from sqlalchemy.orm import Session
from PIL import Image
import imagehash
import io

from models import CheckIn, Tree, Task, User, TaskCompletionLog
from schemas import CheckInAnalysisResponse, AIAnalysis, TaskSchema, PointsSummary
from services.ai_service import AIService
from services.task_service import TaskService


class CheckInService:
    
    MEDIA_DIR = Path("media/checkins")
    DUPLICATE_HASH_THRESHOLD = 5  # Perceptual hash difference threshold
    MAX_DISTANCE_METERS = 300  # Maximum allowed distance from planting location
    
    def __init__(self, db: Session):
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
        """
        Main check-in processing flow
        """
        current_date = datetime.utcnow()
        
        # Ensure user exists
        user = await self._get_or_create_user(user_id)
        
        # Save image and compute hashes
        image_path, file_hash, perceptual_hash, image_bytes = await self._save_and_hash_image(
            image_file
        )
        
        # Determine if this is a new planting or existing tree check-in
        if tree_id is None:
            # NEW PLANTING
            return await self._process_new_planting(
                user_id=user_id,
                latitude=latitude,
                longitude=longitude,
                client_timestamp=client_timestamp,
                image_path=image_path,
                file_hash=file_hash,
                perceptual_hash=perceptual_hash,
                image_bytes=image_bytes,
                current_date=current_date
            )
        else:
            # EXISTING TREE CHECK-IN
            return await self._process_existing_tree_checkin(
                user_id=user_id,
                tree_id=tree_id,
                task_id=task_id,
                latitude=latitude,
                longitude=longitude,
                client_timestamp=client_timestamp,
                phase_hint=phase_hint,
                image_path=image_path,
                file_hash=file_hash,
                perceptual_hash=perceptual_hash,
                image_bytes=image_bytes,
                current_date=current_date
            )
    
    async def _save_and_hash_image(self, image_file: UploadFile):
        """
        Save image to disk and compute file hash and perceptual hash
        """
        # Read image bytes
        image_bytes = await image_file.read()
        
        # Compute file hash (MD5)
        file_hash = hashlib.md5(image_bytes).hexdigest()
        
        # Compute perceptual hash
        image = Image.open(io.BytesIO(image_bytes))
        p_hash = str(imagehash.phash(image))
        
        # Save to disk
        file_extension = os.path.splitext(image_file.filename)[1] or ".jpg"
        filename = f"{uuid.uuid4()}{file_extension}"
        file_path = self.MEDIA_DIR / filename
        
        with open(file_path, "wb") as f:
            f.write(image_bytes)
        
        return str(file_path), file_hash, p_hash, image_bytes
    
    def _calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate distance between two GPS coordinates in meters
        """
        R = 6371000  # Earth radius in meters
        
        lat1_rad = radians(lat1)
        lat2_rad = radians(lat2)
        delta_lat = radians(lat2 - lat1)
        delta_lon = radians(lon2 - lon1)
        
        a = sin(delta_lat / 2) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lon / 2) ** 2
        c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return R * c
    
    def _check_duplicate_submission(
        self, 
        user_id: str, 
        file_hash: str, 
        perceptual_hash: str,
        latitude: float,
        longitude: float,
        current_date: datetime
    ) -> tuple[bool, Optional[str]]:
        """
        Check for duplicate submissions (anti-cheat)
        Returns (is_duplicate, reason)
        """
        # Check exact file hash match
        recent_checkin = self.db.query(CheckIn).filter(
            CheckIn.user_id == user_id,
            CheckIn.image_hash == file_hash
        ).first()
        
        if recent_checkin:
            return True, "EXACT_DUPLICATE"
        
        # Check perceptual hash similarity with recent check-ins in same area
        recent_checkins = self.db.query(CheckIn).filter(
            CheckIn.user_id == user_id,
            CheckIn.timestamp >= current_date.replace(hour=0, minute=0, second=0)
        ).all()
        
        for checkin in recent_checkins:
            # Calculate perceptual hash distance
            p_hash_dist = imagehash.hex_to_hash(perceptual_hash) - imagehash.hex_to_hash(checkin.perceptual_hash)
            
            # Calculate GPS distance
            gps_distance = self._calculate_distance(
                latitude, longitude,
                checkin.latitude, checkin.longitude
            )
            
            # If very similar image in same location
            if p_hash_dist <= self.DUPLICATE_HASH_THRESHOLD and gps_distance < 5:
                return True, "DUPLICATE_TREE"
        
        return False, None
    
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
        """
        Process new seedling planting attempt
        """
        # Check for duplicates
        is_duplicate, duplicate_reason = self._check_duplicate_submission(
            user_id, file_hash, perceptual_hash, latitude, longitude, current_date
        )
        
        if is_duplicate:
            # Save rejected check-in
            checkin = CheckIn(
                user_id=user_id,
                tree_id=None,
                image_path=image_path,
                image_hash=file_hash,
                perceptual_hash=perceptual_hash,
                latitude=latitude,
                longitude=longitude,
                client_timestamp=client_timestamp,
                type="planting",
                cheat_suspected=True,
                accepted=False,
                rejected_reason=duplicate_reason
            )
            self.db.add(checkin)
            self.db.commit()
            
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                cheat_suspected=True,
                error_code=duplicate_reason,
                message="Bu rasm allaqachon yuklangan yoki takroriy",
                points=PointsSummary(awarded=0, penalty=0, total=self.db.query(User).filter(User.id == user_id).first().total_points)
            )
        
        # Analyze image with AI
        ai_result = await self.ai_service.analyze_single_image(image_bytes)
        
        # Check if it's a valid seedling
        if not ai_result["is_seedling"] or ai_result["maturity"] == "mature":
            # Save rejected check-in
            checkin = CheckIn(
                user_id=user_id,
                tree_id=None,
                image_path=image_path,
                image_hash=file_hash,
                perceptual_hash=perceptual_hash,
                latitude=latitude,
                longitude=longitude,
                client_timestamp=client_timestamp,
                type="planting",
                ai_raw_response=ai_result,
                ai_seedling=ai_result["is_seedling"],
                ai_maturity=ai_result["maturity"],
                ai_health=ai_result["health"],
                ai_soil_moisture=ai_result["soil_moisture"],
                accepted=False,
                rejected_reason="NOT_SEEDLING"
            )
            self.db.add(checkin)
            self.db.commit()
            
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                error_code="NOT_SEEDLING",
                message="Faqat yosh ko'chatlar qabul qilinadi",
                analysis=AIAnalysis(**ai_result),
                points=PointsSummary(awarded=0, penalty=0, total=self.db.query(User).filter(User.id == user_id).first().total_points)
            )
        
        # Valid seedling - create new tree
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
            successful_waterings=0,
            initial_bonus_awarded=False
        )
        self.db.add(tree)
        
        # Save check-in
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
        
        self.db.commit()
        
        # Refresh objects
        self.db.refresh(tree)
        for task in initial_tasks:
            self.db.refresh(task)
        
        user = self.db.query(User).filter(User.id == user_id).first()
        
        return CheckInAnalysisResponse(
            status="ANALYZED",
            accepted=True,
            cheat_suspected=False,
            tree_id=tree.id,
            analysis=AIAnalysis(**ai_result),
            new_tasks=[TaskSchema.from_orm(t) for t in initial_tasks],
            updated_tasks=[],
            points=PointsSummary(awarded=0, penalty=0, total=user.total_points)
        )
    
    async def _process_existing_tree_checkin(
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
        """
        Process check-in for existing tree
        """
        # Load tree
        tree = self.db.query(Tree).filter(Tree.id == tree_id).first()
        if not tree:
            raise ValueError(f"Tree {tree_id} not found")
        
        if tree.user_id != user_id:
            raise ValueError("Tree does not belong to this user")
        
        # Check GPS distance from planting location
        distance = self._calculate_distance(
            latitude, longitude,
            tree.latitude, tree.longitude
        )
        
        suspicious_distance = distance > self.MAX_DISTANCE_METERS
        
        # Get previous check-in for comparison
        previous_checkin = self.db.query(CheckIn).filter(
            CheckIn.tree_id == tree_id,
            CheckIn.accepted == True
        ).order_by(CheckIn.timestamp.desc()).first()
        
        # Check for exact duplicate
        if previous_checkin and previous_checkin.image_hash == file_hash:
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
                cheat_suspected=True,
                accepted=False,
                rejected_reason="EXACT_DUPLICATE"
            )
            self.db.add(checkin)
            self.db.commit()
            
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                cheat_suspected=True,
                error_code="EXACT_DUPLICATE",
                message="Bu rasm avval yuklangan",
                tree_id=tree_id,
                points=PointsSummary(awarded=0, penalty=0, total=self.db.query(User).filter(User.id == user_id).first().total_points)
            )
        
        # Analyze with AI (compare with previous if exists)
        if previous_checkin:
            # Load previous image
            with open(previous_checkin.image_path, 'rb') as f:
                previous_image_bytes = f.read()
            
            ai_result = await self.ai_service.compare_images_and_analyze(
                previous_image_bytes, image_bytes
            )
            
            # Check if AI detects same time/angle (cheat)
            if ai_result.get("same_time", False):
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
                    cheat_suspected=True,
                    accepted=False,
                    rejected_reason="SAME_TIME_PHOTO"
                )
                self.db.add(checkin)
                self.db.commit()
                
                return CheckInAnalysisResponse(
                    status="ANALYZED",
                    accepted=False,
                    cheat_suspected=True,
                    error_code="CHEAT_SUSPECTED",
                    message="Rasm bir xil vaqtda olingan ko'rinadi",
                    tree_id=tree_id,
                    points=PointsSummary(awarded=0, penalty=0, total=self.db.query(User).filter(User.id == user_id).first().total_points)
                )
        else:
            # No previous checkin, just analyze current
            ai_result = await self.ai_service.analyze_single_image(image_bytes)
        
        # Handle task completion if task_id provided
        completed_task = None
        awarded_points = 0
        penalty_points = 0
        
        if task_id:
            task = self.db.query(Task).filter(Task.id == task_id).first()
            
            if not task:
                raise ValueError(f"Task {task_id} not found")
            
            # Check if task is already OFF or completed
            if task.status == "off":
                return CheckInAnalysisResponse(
                    status="ANALYZED",
                    accepted=False,
                    error_code="TASK_OFF",
                    message="Bu vazifa muddati o'tgan va bajaririb bo'lmaydi",
                    tree_id=tree_id,
                    points=PointsSummary(awarded=0, penalty=0, total=self.db.query(User).filter(User.id == user_id).first().total_points)
                )
            
            # Check if task is overdue
            if current_date > task.due_date:
                # Apply penalty
                task.status = "off"
                task.penalty_points = -35
                
                user = self.db.query(User).filter(User.id == user_id).first()
                user.total_points += task.penalty_points
                penalty_points = task.penalty_points
                
                # Log penalty
                log = TaskCompletionLog(
                    user_id=user_id,
                    task_id=task_id,
                    delta_points=task.penalty_points,
                    reason="task_late_penalty"
                )
                self.db.add(log)
                self.db.commit()
                
                return CheckInAnalysisResponse(
                    status="ANALYZED",
                    accepted=False,
                    error_code="TASK_LATE",
                    message="Vazifa muddati o'tgan, -35 ball jarimasi qo'llanildi",
                    tree_id=tree_id,
                    updated_tasks=[TaskSchema.from_orm(task)],
                    points=PointsSummary(awarded=0, penalty=penalty_points, total=user.total_points)
                )
            
            # Process task based on type
            if task.type == "watering":
                # Check if watering was successful
                if ai_result.get("soil_moisture") == "dry":
                    # Watering not successful
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
                        ai_maturity=ai_result.get("maturity"),
                        ai_health=ai_result.get("health"),
                        ai_soil_moisture=ai_result.get("soil_moisture"),
                        ai_comment=ai_result.get("comment"),
                        accepted=False,
                        rejected_reason="LOW_MOISTURE"
                    )
                    self.db.add(checkin)
                    self.db.commit()
                    
                    return CheckInAnalysisResponse(
                        status="ANALYZED",
                        accepted=False,
                        error_code="LOW_MOISTURE",
                        message="Tuproq hali ham quruq, qaytadan sug'oring",
                        tree_id=tree_id,
                        analysis=AIAnalysis(
                            is_seedling=ai_result.get("is_seedling", True),
                            maturity=ai_result.get("maturity", "unknown"),
                            health=ai_result.get("health", "unknown"),
                            soil_moisture=ai_result.get("soil_moisture", "dry"),
                            comment=ai_result.get("comment", "")
                        ),
                        points=PointsSummary(awarded=0, penalty=0, total=self.db.query(User).filter(User.id == user_id).first().total_points)
                    )
                
                # Watering successful
                task.status = "completed"
                task.completed_at = current_date
                awarded_points = task.reward_points
                
                tree.successful_waterings += 1
                
                # Check if this is the second successful step (planting + first watering)
                if not tree.initial_bonus_awarded and tree.successful_waterings == 1:
                    # Award initial bonus
                    bonus = 50
                    awarded_points += bonus
                    tree.initial_bonus_awarded = True
                    
                    # Log bonus
                    bonus_log = TaskCompletionLog(
                        user_id=user_id,
                        task_id=task_id,
                        delta_points=bonus,
                        reason="initial_bonus"
                    )
                    self.db.add(bonus_log)
                
                completed_task = task
            
            elif task.type in ["photo_check", "closeup_photo", "clean_area"]:
                # Complete photo/monitoring task
                task.status = "completed"
                task.completed_at = current_date
                awarded_points = task.reward_points
                completed_task = task
            
            # Update user points
            if awarded_points > 0:
                user = self.db.query(User).filter(User.id == user_id).first()
                user.total_points += awarded_points
                
                # Log completion
                log = TaskCompletionLog(
                    user_id=user_id,
                    task_id=task_id,
                    delta_points=awarded_points,
                    reason="task_completed"
                )
                self.db.add(log)
        
        # Save check-in
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
            ai_maturity=ai_result.get("maturity"),
            ai_health=ai_result.get("health"),
            ai_soil_moisture=ai_result.get("soil_moisture"),
            ai_comment=ai_result.get("comment") or ai_result.get("changes"),
            accepted=True,
            cheat_suspected=suspicious_distance
        )
        self.db.add(checkin)
        
        # Update tree status
        tree.last_health = ai_result.get("health")
        tree.last_soil_moisture = ai_result.get("soil_moisture")
        tree.last_analysis_at = current_date
        tree.phase = self.task_service.get_tree_phase(tree, current_date)
        
        # Generate new tasks
        new_tasks = await self.task_service.generate_next_tasks(
            tree,
            ai_result.get("health", "unknown"),
            ai_result.get("soil_moisture", "unknown"),
            current_date
        )
        for new_task in new_tasks:
            self.db.add(new_task)
        
        self.db.commit()
        
        # Refresh objects
        for new_task in new_tasks:
            self.db.refresh(new_task)
        
        user = self.db.query(User).filter(User.id == user_id).first()
        
        updated_tasks = [TaskSchema.from_orm(completed_task)] if completed_task else []
        
        return CheckInAnalysisResponse(
            status="ANALYZED",
            accepted=True,
            cheat_suspected=suspicious_distance,
            tree_id=tree_id,
            task_id=task_id,
            analysis=AIAnalysis(
                is_seedling=ai_result.get("is_seedling", True),
                maturity=ai_result.get("maturity", "unknown"),
                health=ai_result.get("health", "unknown"),
                soil_moisture=ai_result.get("soil_moisture", "unknown"),
                comment=ai_result.get("comment") or ai_result.get("changes", "")
            ),
            new_tasks=[TaskSchema.from_orm(t) for t in new_tasks],
            updated_tasks=updated_tasks,
            points=PointsSummary(
                awarded=awarded_points,
                penalty=penalty_points,
                total=user.total_points
            )
        )
    
    async def _get_or_create_user(self, user_id: str) -> User:
        """Get existing user or create new one"""
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            user = User(id=user_id, total_points=0)
            self.db.add(user)
            self.db.commit()
            self.db.refresh(user)
        return user
