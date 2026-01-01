"""
Complete check-in processing service
Fixed: Location tolerance increased, plant detection improved
"""
import hashlib
import os
from datetime import datetime, timedelta
from typing import Optional, Dict
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

    # GPS MASOFALAR - KENGAYTIRILGAN (GPS xatoliklari uchun)
    MAX_DISTANCE_METERS_OWNER = 150     # Daraxt egasi uchun 150 metr (oldin 50)
    MAX_DISTANCE_METERS_PUBLIC = 200    # Boshqa foydalanuvchilar uchun 200 metr (oldin 100)
    
    # Sug'orish uchun alohida (yanada yumshoq)
    MAX_DISTANCE_METERS_WATERING = 250  # Sug'orish uchun 250 metr

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

        # EXISTING TREE (watering, photo_check, etc.)
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
        """Distance in meters using Haversine formula"""
        R = 6371000  # Earth radius in meters
        
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
        """Process new tree/plant planting - YUMSHATILGAN FILTER"""

        # Check duplicates (exact file hash in last 1 hour)
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
        maturity = ai_result.get("maturity", "unknown")
        # YUMSHATILGAN VALIDATSIYA - yangi format
        rejection_code = None
        error_messages = {
            "NOT_PLANT": "Bu o'simlik emas. Iltimos, daraxt, ko'chat, gul yoki xonaki o'simlik rasmini yuklang.",
            "FAKE_PHOTO": "Bu haqiqiy surat emas. Iltimos, jonli rasm oling.",
            "TOO_BIG": "Bu daraxt juda katta (2.5+ metr). Faqat yosh va kichik o'simliklar qabul qilinadi.",
            "TOO_THICK": "Bu daraxt juda yo'g'on tanali. Bu tabiiy o'sgan daraxt, odam ekmagan.",
        }

        is_plant = ai_result.get("is_plant", ai_result.get("is_tree", False))
        is_real = ai_result.get("is_real_photo", True)
        is_acceptable = ai_result.get("is_acceptable", True)
        rejection_reason = ai_result.get("rejection_reason")
        
        size_analysis = ai_result.get("size_analysis", {})
        is_too_tall = size_analysis.get("is_too_tall", False)
        is_too_thick = size_analysis.get("is_trunk_too_thick", False)

        # Validatsiya
        if not is_plant:
            rejection_code = "NOT_PLANT"
        elif not is_real:
            rejection_code = "FAKE_PHOTO"
        elif is_too_tall or (rejection_reason == "TOO_BIG"):
            rejection_code = "TOO_BIG"
        elif is_too_thick or (rejection_reason == "TOO_THICK"):
            rejection_code = "TOO_THICK"
        elif not is_acceptable and rejection_reason:
            rejection_code = rejection_reason

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
                ai_tree=is_plant,
                ai_real_photo=is_real,
                ai_seedling=ai_result.get("is_seedling"),
                ai_maturity=maturity,
                ai_health=ai_result.get("health"),
                ai_soil_moisture=ai_result.get("soil_moisture"),
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
                analysis=self._create_ai_analysis(ai_result),
                points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
            )

        # QABUL QILINDI - O'simlik yaratish
        # Phase ni AI natijasiga qarab belgilaymiz
        maturity = ai_result.get("maturity", "unknown")
        phase = maturity if maturity in ["seedling", "young", "mature", "houseplant"] else "seedling"
        
        # O'simlik nomi (comment uchun)
        plant_info = ai_result.get("plant_info", {})
        plant_name = plant_info.get("name_uzbek") or plant_info.get("name_common") or "Noma'lum o'simlik"

        tree = Tree(
            id=str(uuid.uuid4()),
            user_id=user_id,
            latitude=latitude,
            longitude=longitude,
            phase=phase,
            status="active",
            last_health=ai_result.get("health"),
            last_soil_moisture=ai_result.get("soil_moisture"),
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
            ai_tree=is_plant,
            ai_real_photo=is_real,
            ai_seedling=ai_result.get("is_seedling"),
            ai_maturity=maturity,
            ai_health=ai_result.get("health"),
            ai_soil_moisture=ai_result.get("soil_moisture"),
            ai_comment=ai_result.get("comment"),
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
            analysis=self._create_ai_analysis(ai_result),
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
        """Process check-in for existing tree - YUMSHATILGAN LOKATSIYA"""

        # Load tree
        tree_q = select(Tree).where(Tree.id == tree_id)
        tree_r = await self.db.execute(tree_q)
        tree = tree_r.scalar_one_or_none()

        if not tree:
            raise ValueError("Daraxt topilmadi")

        # Check GPS distance - KENGAYTIRILGAN TOLERANS
        is_owner = (tree.user_id == user_id)
        is_watering = phase_hint == "watering" or (task_id is not None)
        
        # Vazifa turiga qarab masofa
        if is_watering:
            max_distance = self.MAX_DISTANCE_METERS_WATERING  # 250m
        elif is_owner:
            max_distance = self.MAX_DISTANCE_METERS_OWNER  # 150m
        else:
            max_distance = self.MAX_DISTANCE_METERS_PUBLIC  # 200m

        # Use centroid if available, otherwise use original coordinates
        tree_lat = tree.centroid_lat if tree.centroid_lat else tree.latitude
        tree_lon = tree.centroid_lon if tree.centroid_lon else tree.longitude

        distance = self._calculate_distance(
            latitude, longitude,
            tree_lat, tree_lon
        )

        # LOG distance for debugging
        print(f"[CheckIn] Distance check: user=({latitude}, {longitude}), tree=({tree_lat}, {tree_lon}), distance={distance}m, max={max_distance}m")

        # MUHIM: Juda uzoq bo'lsagina rad etamiz
        if distance > max_distance:
            user = await self._get_user(user_id)
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                error_code="LOCATION_MISMATCH",
                message=f"Siz o'simlikdan {int(distance)}m uzoqdasiz. Iltimos, yaqinroq boring (max: {int(max_distance)}m)",
                tree_id=tree_id,
                points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
            )

        # Get previous checkin for comparison
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

        # AI Analysis - sug'orish uchun maxsus
        if phase_hint == "watering" or (task_id is not None):
            # Vazifa bor - sug'orish yoki tekshiruv
            if previous_checkin:
                with open(previous_checkin.image_path, 'rb') as f:
                    prev_bytes = f.read()
                
                # Yangi comparison method ishlatamiz
                task_type = phase_hint or "photo_check"
                ai_result = await self.ai_service.compare_images_for_task(prev_bytes, image_bytes, task_type)

                # Bir xil o'simlik emasmi tekshirish
                if not ai_result.get("is_same_plant", True):
                    confidence = ai_result.get("confidence_percent", 0)
                    user = await self._get_user(user_id)
                    return CheckInAnalysisResponse(
                        status="ANALYZED",
                        accepted=False,
                        error_code="DIFFERENT_PLANT",
                        message=f"Bu boshqa o'simlik. Iltimos, ro'yxatdagi o'simlikni rasmga oling. (O'xshashlik: {confidence}%)",
                        tree_id=tree_id,
                        analysis=self._create_ai_analysis(ai_result),
                        points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
                    )

                # Firibgarlik tekshiruvi
                if ai_result.get("is_fraud_attempt"):
                    fraud_reason = ai_result.get("fraud_reason", "UNKNOWN")
                    user = await self._get_user(user_id)
                    return CheckInAnalysisResponse(
                        status="ANALYZED",
                        accepted=False,
                        cheat_suspected=True,
                        error_code=f"FRAUD_{fraud_reason}",
                        message="Firibgarlik aniqlandi. Iltimos, haqiqiy rasm yuboring.",
                        tree_id=tree_id,
                        points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
                    )

                # same_scene tekshiruvi
                if ai_result.get("same_scene", False):
                    user = await self._get_user(user_id)
                    return CheckInAnalysisResponse(
                        status="ANALYZED",
                        accepted=False,
                        cheat_suspected=True,
                        error_code="SAME_SCENE",
                        message="Bu xuddi oldingi rasm. Iltimos, yangi rasm oling.",
                        tree_id=tree_id,
                        points=PointsSummary(awarded=0, penalty=0, total=user.total_points if user else 0)
                    )
            else:
                # Birinchi marta - oddiy analyze qilamiz
                ai_result = await self.ai_service.analyze_single_image(image_bytes)
        else:
            # Oddiy monitoring
            if previous_checkin:
                with open(previous_checkin.image_path, 'rb') as f:
                    prev_bytes = f.read()
                ai_result = await self.ai_service.compare_images_for_task(prev_bytes, image_bytes, "photo_check")
            else:
                ai_result = await self.ai_service.analyze_single_image(image_bytes)

        # Validatsiya - juda yumshoq
        # Faqat aniq fake bo'lsa rad etamiz
        if ai_result.get("is_real_photo") == False:
            user = await self._get_user(user_id)
            return CheckInAnalysisResponse(
                status="ANALYZED",
                accepted=False,
                error_code="FAKE_PHOTO",
                message="Bu haqiqiy surat emas",
                tree_id=tree_id,
                analysis=self._create_ai_analysis(ai_result),
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
            if current_date > task.due_date + timedelta(hours=24) and task.status == "pending":
                # 24 soatdan oshgan - jarima
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
                    message="Vazifa muddati o'tgan (24+ soat), -35 ball jarimasi",
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

            # Check reservation timeout - 30 daqiqa -> 60 daqiqaga oshirdik
            if task.status == "claimed" and task.assigned_user_id == user_id and task.claimed_at:
                if current_date > task.claimed_at + timedelta(minutes=60):
                    # 60 daqiqa o'tdi - jarima
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
                        message="Vazifa vaqti tugagan (60 daqiqa), -30 ball jarimasi",
                        tree_id=tree_id,
                        points=PointsSummary(awarded=0, penalty=penalty_points, total=user.total_points)
                    )

            # Complete task - sug'orish uchun moisture tekshiruvi OLIB TASHLANDI
            # Endi ixtiyoriy rasm bilan ham qabul qilinadi
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
            ai_tree=ai_result.get("is_tree", True),
            ai_real_photo=ai_result.get("is_real_photo", True),
            ai_seedling=ai_result.get("is_seedling"),
            ai_maturity=ai_result.get("maturity"),
            ai_health=ai_result.get("health"),
            ai_soil_moisture=ai_result.get("soil_moisture"),
            ai_comment=ai_result.get("comment") or ai_result.get("changes"),
            accepted=True
        )
        self.db.add(checkin)

        # Update tree
        tree.last_health = ai_result.get("health") or tree.last_health
        tree.last_soil_moisture = ai_result.get("soil_moisture") or tree.last_soil_moisture
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
            analysis=self._create_ai_analysis(ai_result),
            new_tasks=[TaskSchema.from_orm(t) for t in new_tasks],
            updated_tasks=updated_tasks,
            points=PointsSummary(
                awarded=awarded_points,
                penalty=penalty_points,
                total=user.total_points if user else 0
            )
        )

    def _create_ai_analysis(self, ai_result: Dict) -> Optional[AIAnalysis]:
        """Create AIAnalysis from result dict"""
        try:
            return AIAnalysis(
                is_tree=ai_result.get("is_tree", ai_result.get("is_plant", True)),
                is_real_photo=ai_result.get("is_real_photo", True),
                is_seedling=ai_result.get("is_seedling", False),
                maturity=ai_result.get("maturity", "unknown"),
                health=ai_result.get("health", "unknown"),
                soil_moisture=ai_result.get("soil_moisture", "unknown"),
                comment=ai_result.get("comment", "")
            )
        except:
            return None

    async def _get_user(self, user_id: str) -> Optional[User]:
        query = select(User).where(User.id == user_id)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()
