"""
GreenTech Backend - Complete System with Combined Trees (DB + Satellite)
Port: 5512
Database: PostgreSQL (Async)
"""
from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from datetime import datetime
import uvicorn

from database import get_db, init_db
from schemas import *
from services.auth_service import AuthService
from services.checkin_service import CheckInService
from services.task_service import TaskService
from services.rating_service import RatingService
from services.nearby_trees_service import NearbyTreesService

app = FastAPI(
    title="GreenTech Complete API",
    version="6.0.0",
    description="Full backend with combined user-planted and satellite trees",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    """Initialize database"""
    await init_db()
    print("✅ Database initialized on port 5512")
    print("✅ Nearby Trees Service ready (DB + Satellite)")


@app.get("/")
async def root():
    return {
        "status": "ok",
        "service": "GreenTech Complete API",
        "version": "6.0.0",
        "port": 5512,
        "features": ["auth", "checkins", "tasks", "rating", "combined_nearby_trees"]
    }


# ============================================================================
# AUTHENTICATION
# ============================================================================

@app.post("/api/v1/auth/register", response_model=AuthResponse, tags=["Auth"])
async def register(
    request: UserRegisterRequest,
    db: AsyncSession = Depends(get_db)
):
    auth_service = AuthService(db)
    success, message, user = await auth_service.register_user(
        phone_number=request.phone_number,
        full_name=request.full_name,
        password=request.password
    )

    if not success:
        raise HTTPException(status_code=400, detail=message)

    token = auth_service.generate_token(user.id)

    return AuthResponse(
        success=True,
        message=message,
        user=UserResponse.from_orm(user),
        token=token
    )


@app.post("/api/v1/auth/login", response_model=AuthResponse, tags=["Auth"])
async def login(
    request: UserLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    auth_service = AuthService(db)
    success, message, user, token = await auth_service.login_user(
        phone_number=request.phone_number,
        password=request.password
    )

    if not success:
        raise HTTPException(status_code=400, detail=message)

    return AuthResponse(
        success=True,
        message=message,
        user=UserResponse.from_orm(user),
        token=token
    )


@app.get("/api/v1/auth/me", response_model=UserResponse, tags=["Auth"])
async def get_current_user(
    token: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    auth_service = AuthService(db)
    user = await auth_service.verify_token(token)

    if not user:
        raise HTTPException(status_code=401, detail="Token noto'g'ri")

    return UserResponse.from_orm(user)


# ============================================================================
# CHECK-IN
# ============================================================================

@app.post("/api/v1/checkins/analyze", response_model=CheckInAnalysisResponse, tags=["Check-ins"])
async def analyze_checkin(
    user_id: str = Form(...),
    tree_id: Optional[str] = Form(None),
    task_id: Optional[str] = Form(None),
    latitude: float = Form(...),
    longitude: float = Form(...),
    client_timestamp: str = Form(...),
    phase_hint: Optional[str] = Form(None),
    image: UploadFile = File(...),
    db: AsyncSession = Depends(get_db)
):
    service = CheckInService(db)

    try:
        result = await service.process_checkin(
            user_id=user_id,
            tree_id=tree_id,
            task_id=task_id,
            latitude=latitude,
            longitude=longitude,
            client_timestamp=client_timestamp,
            phase_hint=phase_hint,
            image_file=image
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server xatosi: {str(e)}")


# ============================================================================
# NEARBY TREES - COMBINED (DB + SATELLITE) - YANGI!
# ============================================================================

@app.get("/api/v1/trees/nearby", tags=["Trees"])
async def get_nearby_trees(
    lat: float = Query(..., description="User's latitude"),
    lon: float = Query(..., description="User's longitude"),
    radius_km: float = Query(2.0, ge=0.1, le=10, description="Search radius in km"),
    limit: int = Query(50, ge=1, le=200, description="Max results"),
    include_satellite: bool = Query(True, description="Include satellite trees"),
    include_user_planted: bool = Query(True, description="Include user-planted trees"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get nearby trees from BOTH sources:
    - User-planted trees (from database)
    - Satellite-detected trees (from JSON)
    
    Returns trees sorted by distance (closest first)
    
    Response includes 'source' field:
    - "user_planted" = foydalanuvchi ekgan daraxt
    - "satellite" = sun'iy yo'ldoshdan aniqlangan
    """
    try:
        service = NearbyTreesService(db=db)
        
        trees = await service.get_nearby_trees(
            user_lat=lat,
            user_lon=lon,
            radius_km=radius_km,
            limit=limit,
            include_satellite=include_satellite,
            include_user_planted=include_user_planted
        )
        
        return {
            "success": True,
            "count": len(trees),
            "radius_km": radius_km,
            "user_location": {"lat": lat, "lon": lon},
            "sources": {
                "satellite_enabled": include_satellite,
                "user_planted_enabled": include_user_planted
            },
            "trees": trees
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/trees/details/{tree_id}", tags=["Trees"])
async def get_tree_details(
    tree_id: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed information about a specific tree
    
    Works for both:
    - User-planted trees (UUID format)
    - Satellite trees (sat_* format)
    """
    try:
        service = NearbyTreesService(db=db)
        tree = await service.get_tree_details(tree_id)
        
        if not tree:
            raise HTTPException(status_code=404, detail="Tree not found")
        
        return {
            "success": True,
            "tree": tree
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/trees/bounds", tags=["Trees"])
async def get_trees_in_bounds(
    north: float = Query(..., description="Northern boundary"),
    south: float = Query(..., description="Southern boundary"),
    east: float = Query(..., description="Eastern boundary"),
    west: float = Query(..., description="Western boundary"),
    include_satellite: bool = Query(True),
    include_user_planted: bool = Query(True),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all trees within a bounding box
    
    Useful for map view rendering - returns all trees in viewport
    """
    try:
        service = NearbyTreesService(db=db)
        
        trees = await service.get_trees_in_bounds(
            north=north,
            south=south,
            east=east,
            west=west,
            include_satellite=include_satellite,
            include_user_planted=include_user_planted
        )
        
        return {
            "success": True,
            "count": len(trees),
            "bounds": {
                "north": north,
                "south": south,
                "east": east,
                "west": west
            },
            "trees": trees
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/trees/statistics", tags=["Trees"])
async def get_tree_statistics(
    db: AsyncSession = Depends(get_db)
):
    """
    Get statistics about all trees in the system
    
    Shows counts for:
    - User-planted trees (from database)
    - Satellite trees (from JSON)
    - Total trees
    """
    try:
        service = NearbyTreesService(db=db)
        stats = await service.get_statistics()
        
        return {
            "success": True,
            "statistics": stats
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# TASKS
# ============================================================================

@app.post("/api/v1/tasks/nearby", response_model=NearbyTasksResponse, tags=["Tasks"])
async def get_nearby_tasks(
    request: NearbyTasksRequest,
    db: AsyncSession = Depends(get_db)
):
    task_service = TaskService(db)

    try:
        await task_service.release_expired_reservations()

        tasks = await task_service.get_nearby_tasks(
            user_id=request.user_id,
            latitude=request.latitude,
            longitude=request.longitude
        )

        return NearbyTasksResponse(
            user_id=request.user_id,
            now=datetime.utcnow().isoformat(),
            tasks=tasks
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/tasks/claim", response_model=TaskClaimResponse, tags=["Tasks"])
async def claim_task(
    request: TaskClaimRequest,
    db: AsyncSession = Depends(get_db)
):
    task_service = TaskService(db)

    try:
        await task_service.release_expired_reservations()

        success, message, task = await task_service.claim_task(
            user_id=request.user_id,
            task_id=request.task_id
        )

        if not success:
            raise HTTPException(status_code=400, detail=message)

        return TaskClaimResponse(
            success=True,
            message=message,
            task=task
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# MY TREES
# ============================================================================

@app.get("/api/v1/users/{user_id}/trees", response_model=MyTreesResponse, tags=["My Trees"])
async def get_my_trees(
    user_id: str,
    db: AsyncSession = Depends(get_db)
):
    task_service = TaskService(db)

    try:
        trees = await task_service.get_user_trees_with_tasks(user_id)

        return MyTreesResponse(
            user_id=user_id,
            trees=trees
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/trees/{tree_id}", response_model=TreeDetailResponse, tags=["My Trees"])
async def get_tree_detail(
    tree_id: str,
    db: AsyncSession = Depends(get_db)
):
    task_service = TaskService(db)

    try:
        tree_detail = await task_service.get_tree_detail(tree_id)

        if not tree_detail:
            raise HTTPException(status_code=404, detail="Daraxt topilmadi")

        return tree_detail
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# RATING
# ============================================================================

@app.get("/api/v1/users/rating", response_model=RatingResponse, tags=["Rating"])
async def get_rating(
    range: str = Query("7d", description="7d, 30d, custom"),
    from_date: Optional[str] = Query(None, alias="from"),
    to_date: Optional[str] = Query(None, alias="to"),
    db: AsyncSession = Depends(get_db)
):
    rating_service = RatingService(db)

    try:
        leaderboard = await rating_service.get_leaderboard(
            range_type=range,
            from_date=from_date,
            to_date=to_date
        )

        return RatingResponse(
            range_type=range,
            from_date=from_date,
            to_date=to_date,
            items=leaderboard
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/users/{user_id}/stats", response_model=UserStatsResponse, tags=["Rating"])
async def get_user_stats(
    user_id: str,
    db: AsyncSession = Depends(get_db)
):
    rating_service = RatingService(db)

    try:
        stats = await rating_service.get_user_stats(user_id)
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# LEGACY ENDPOINTS (Backward Compatibility)
# ============================================================================

@app.post("/api/v1/trees/nearby", tags=["Trees (Legacy)"])
async def legacy_nearby_trees(
    request: NearbyTreesSearchRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    LEGACY: POST method for backward compatibility
    Use GET /api/v1/trees/nearby instead
    """
    try:
        service = NearbyTreesService(db=db)
        
        trees = await service.get_nearby_trees(
            user_lat=request.latitude,
            user_lon=request.longitude,
            radius_km=request.radius_km,
            limit=request.limit,
            include_satellite=True,
            include_user_planted=True
        )
        
        return {
            "user_location": {
                "latitude": request.latitude,
                "longitude": request.longitude
            },
            "radius_km": request.radius_km,
            "total_found": len(trees),
            "trees": trees
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



# main.py ga QO'SHILISHI KERAK BO'LGAN YANGI ENDPOINTLAR
# Mavjud endpointlar bilan birga ishlaydi

from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timedelta
import locale

# Import yangi servislar
from services.tree_health_service import TreeHealthService
from services.enhanced_task_service import EnhancedTaskService


# ============================================================================
# 1. TREE HEALTH STATUS API
# ============================================================================

@app.get("/api/v1/trees/{tree_id}/health", tags=["Tree Health"])
async def get_tree_health_status(
    tree_id: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Daraxt salomatlik holati va tarixini olish
    
    Qaytaradi:
    - Joriy salomatlik holati
    - Namlik darajasi
    - Oxirgi AI tahlili
    - Salomatlik tendentsiyasi
    - Tarix (oxirgi 10 ta tekshiruv)
    
    Misol:
    GET /api/v1/trees/abc123/health
    """
    try:
        service = TreeHealthService(db)
        health_data = await service.get_tree_health_status(tree_id)
        
        if not health_data:
            raise HTTPException(status_code=404, detail="Daraxt topilmadi")
        
        return {
            "success": True,
            "data": health_data
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/trees/{tree_id}/health/history", tags=["Tree Health"])
async def get_tree_health_history(
    tree_id: str,
    limit: int = Query(20, ge=1, le=100, description="Nechta yozuv"),
    db: AsyncSession = Depends(get_db)
):
    """
    Daraxt salomatlik tarixini olish
    
    Qaytaradi oxirgi N ta tekshiruvni chronologic tartibda
    
    Misol:
    GET /api/v1/trees/abc123/health/history?limit=30
    """
    try:
        service = TreeHealthService(db)
        history = await service.get_health_history(tree_id, limit)
        
        return {
            "success": True,
            "tree_id": tree_id,
            "total": len(history),
            "history": history
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# 2. ENHANCED TREE DETAILS API
# ============================================================================

@app.get("/api/v1/trees/{tree_id}/full", tags=["Trees"])
async def get_full_tree_details(
    tree_id: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Daraxt to'liq ma'lumotlari (barcha detallar)
    
    Qaytaradi:
    - Asosiy ma'lumotlar (ekilgan sana, joy, rasm)
    - Joriy holat (salomatlik, namlik, yetuklik)
    - Oxirgi AI tahlili (batafsil)
    - Barcha vazifalar (active, completed)
    - Statistika (sug'orish, tekshiruvlar)
    - Rasmlar tarixi
    
    Bu endpoint barcha kerakli ma'lumotlarni bitta so'rovda beradi!
    
    Misol:
    GET /api/v1/trees/abc123/full
    """
    try:
        service = TreeHealthService(db)
        details = await service.get_full_tree_details(tree_id)
        
        if not details:
            raise HTTPException(status_code=404, detail="Daraxt topilmadi")
        
        return {
            "success": True,
            "tree": details
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# 3. TASK COMPLETION WITH IMAGE (MANDATORY)
# ============================================================================

@app.post("/api/v1/tasks/{task_id}/complete", tags=["Tasks"])
async def complete_task_with_image(
    task_id: str,
    user_id: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    client_timestamp: str = Form(...),
    image: UploadFile = File(..., description="Vazifa uchun rasm MAJBURIY"),
    db: AsyncSession = Depends(get_db)
):
    """
    Vazifani rasm bilan bajarish (RASM MAJBURIY!)
    
    Har qanday vazifa turi uchun rasm yuborish shart:
    - watering: Sug'orilgan daraxt rasmi
    - photo_check: Daraxt holati rasmi
    - fertilizing: O'g'itlangan joy rasmi
    - pruning: Qirqilgan/tozalangan rasm
    - pest_check: Zararkunandalar tekshiruv rasmi
    
    AI rasm orqali:
    1. Vazifa to'g'ri bajarilganini tekshiradi
    2. Daraxt holatini tahlil qiladi
    3. Batafsil feedback beradi
    4. Keyingi vazifalarni yaratadi
    
    Misol:
    POST /api/v1/tasks/task123/complete
    Form data:
    - user_id: user123
    - latitude: 41.2995
    - longitude: 69.2401
    - client_timestamp: 2024-01-15T10:30:00
    - image: [FILE]
    """
    try:
        service = EnhancedTaskService(db)
        result = await service.complete_task_with_validation(
            task_id=task_id,
            user_id=user_id,
            latitude=latitude,
            longitude=longitude,
            client_timestamp=client_timestamp,
            image_file=image
        )
        
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server xatosi: {str(e)}")


# ============================================================================
# 4. NEARBY TASKS (ENHANCED WITH TIME FORMATTING)
# ============================================================================

@app.get("/api/v1/tasks/nearby/enhanced", tags=["Tasks"])
async def get_nearby_tasks_enhanced(
    user_id: str = Query(...),
    latitude: float = Query(...),
    longitude: float = Query(...),
    radius_km: float = Query(2.0, ge=0.5, le=10.0),
    db: AsyncSession = Depends(get_db)
):
    """
    Yaqin atrofdagi vazifalar (kengaytirilgan)
    
    Farqi:
    - Vaqt odam tushunadigan formatda ("2 soat 30 daqiqa")
    - Masofa o'zbek tilida ("1.5 km" yoki "250 metr")
    - Daraxt egasining ismi
    - Vazifa batafsil tavsifi
    - Band qilish imkoniyati va muddat
    
    Faqat vaqti kelgan yoki yaqinlashgan vazifalar ko'rsatiladi!
    Vaqti kelmagan vazifalarni band qilib bo'lmaydi.
    
    Misol:
    GET /api/v1/tasks/nearby/enhanced?user_id=user123&latitude=41.2995&longitude=69.2401&radius_km=2
    """
    try:
        service = EnhancedTaskService(db)
        tasks = await service.get_nearby_tasks_enhanced(
            user_id=user_id,
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km
        )
        
        return {
            "success": True,
            "user_location": {"lat": latitude, "lon": longitude},
            "radius_km": radius_km,
            "total": len(tasks),
            "available_tasks": tasks
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/tasks/{task_id}/claim/enhanced", tags=["Tasks"])
async def claim_task_enhanced(
    task_id: str,
    user_id: str = Query(..., description="User ID"),
    db: AsyncSession = Depends(get_db)
):
    """
    Vazifani band qilish (kengaytirilgan)
    
    Shartlar:
    - Vazifa vaqti kelgan bo'lishi kerak (yoki 24 soat ichida)
    - Boshqa user band qilmagan bo'lishi kerak
    - Band qilgandan keyin 30 daqiqa ichida bajarish shart
    - Aks holda -30 ball jarima va vazifa bo'shaydi
    
    Misol:
    POST /api/v1/tasks/task123/claim/enhanced?user_id=user123
    """
    try:
        service = EnhancedTaskService(db)
        result = await service.claim_task_enhanced(task_id, user_id)
        
        if not result['success']:
            raise HTTPException(status_code=400, detail=result['message'])
        
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# 5. GLOBAL STATISTICS
# ============================================================================

@app.get("/api/v1/statistics/global", tags=["Statistics"])
async def get_global_statistics(
    db: AsyncSession = Depends(get_db)
):
    """
    Global tizim statistikasi
    
    Qaytaradi:
    - Jami ekilgan daraxtlar soni
    - Faol daraxtlar soni
    - Jami foydalanuvchilar
    - Bajarilgan vazifalar
    - O'rtacha daraxt salomatligi
    - Holat bo'yicha taqsimlash
    - Oxirgi 7 va 30 kundagi ekinlar
    
    Misol:
    GET /api/v1/statistics/global
    """
    try:
        from services.statistics_service import StatisticsService
        service = StatisticsService(db)
        stats = await service.get_global_statistics()
        
        return {
            "success": True,
            "statistics": stats,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# 6. RATING / LEADERBOARD (ENHANCED)
# ============================================================================

@app.get("/api/v1/rating/leaderboard", tags=["Rating"])
async def get_enhanced_leaderboard(
    period: str = Query("7days", regex="^(7days|30days|all_time)$"),
    limit: int = Query(50, ge=10, le=200),
    db: AsyncSession = Depends(get_db)
):
    """
    Lider taxtasi (kengaytirilgan)
    
    Parametrlar:
    - period: "7days" (7 kun), "30days" (30 kun), "all_time" (Barcha vaqt)
    - limit: Ko'rsatiladigan foydalanuvchilar soni (10-200)
    
    Qaytaradi har bir user uchun:
    - Joylanish (rank)
    - Umumiy ballari
    - Bajarilgan vazifalar
    - Ekilgan daraxtlar
    - G'amxo'rlik bahosi (0-100)
    - Oxirgi faollik
    
    O'zbek tilida vaqt ko'rsatiladi: "7 kun", "30 kun", "Barcha vaqt"
    
    Misol:
    GET /api/v1/rating/leaderboard?period=7days&limit=100
    """
    try:
        from services.rating_enhanced_service import RatingEnhancedService
        service = RatingEnhancedService(db)
        
        period_map = {
            "7days": ("7 kun", 7),
            "30days": ("30 kun", 30),
            "all_time": ("Barcha vaqt", None)
        }
        
        period_label, days = period_map[period]
        leaderboard = await service.get_enhanced_leaderboard(days, limit)
        
        return {
            "success": True,
            "period": period_label,
            "period_start": (datetime.utcnow() - timedelta(days=days)).isoformat() if days else None,
            "period_end": datetime.utcnow().isoformat(),
            "total_shown": len(leaderboard),
            "leaderboard": leaderboard
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# 7. USER'S OWN TREES WITH FULL DETAILS
# ============================================================================

@app.get("/api/v1/users/{user_id}/trees/detailed", tags=["My Trees"])
async def get_user_trees_detailed(
    user_id: str,
    include_completed: bool = Query(False, description="Tugatilgan vazifalarni qo'shish"),
    db: AsyncSession = Depends(get_db)
):
    """
    Foydalanuvchi daraxtlari (batafsil)
    
    Har bir daraxt uchun:
    - Asosiy ma'lumotlar va rasm
    - Joriy holat va salomatlik
    - Active vazifalar (vaqt bilan)
    - Oxirgi AI tahlili
    - Statistika
    
    Bu endpoint mobile app uchun moslashtirilgan:
    - Vaqtlar odam tushunadigan ("3 kun oldin")
    - Rasmlar URL bilan
    - Vazifalar uchun countdown
    
    Misol:
    GET /api/v1/users/user123/trees/detailed
    """
    try:
        service = TreeHealthService(db)
        trees = await service.get_user_trees_detailed(user_id, include_completed)
        
        return {
            "success": True,
            "user_id": user_id,
            "total_trees": len(trees),
            "trees": trees
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# HELPER FUNCTIONS FOR TIME FORMATTING
# ============================================================================

def format_relative_time(target_date: datetime) -> str:
    """
    Vaqtni o'zbek tilida formatlash
    
    Misol:
    - "2 daqiqa ichida"
    - "1 soat 15 daqiqa ichida"
    - "Bugun 18:00"
    - "Ertaga"
    - "3 kun ichida"
    - "2 hafta oldin"
    """
    now = datetime.utcnow()
    delta = target_date - now
    
    if delta.total_seconds() < 0:
        # O'tgan vaqt
        delta = -delta
        if delta.days > 30:
            months = delta.days // 30
            return f"{months} oy oldin"
        elif delta.days > 0:
            return f"{delta.days} kun oldin"
        elif delta.seconds >= 3600:
            hours = delta.seconds // 3600
            return f"{hours} soat oldin"
        elif delta.seconds >= 60:
            minutes = delta.seconds // 60
            return f"{minutes} daqiqa oldin"
        else:
            return "Hozir"
    else:
        # Kelajak vaqt
        if delta.days > 30:
            months = delta.days // 30
            return f"{months} oy ichida"
        elif delta.days > 1:
            return f"{delta.days} kun ichida"
        elif delta.days == 1:
            return f"Ertaga {target_date.strftime('%H:%M')}"
        elif delta.seconds >= 3600:
            hours = delta.seconds // 3600
            minutes = (delta.seconds % 3600) // 60
            if minutes > 0:
                return f"{hours} soat {minutes} daqiqa ichida"
            return f"{hours} soat ichida"
        elif delta.seconds >= 60:
            minutes = delta.seconds // 60
            return f"{minutes} daqiqa ichida"
        else:
            return "Darhol"


def format_distance(meters: float) -> str:
    """
    Masofani o'zbek tilida formatlash
    
    Misol:
    - "50 metr"
    - "1.2 km"
    """
    if meters < 1000:
        return f"{int(meters)} metr"
    else:
        km = meters / 1000
        return f"{km:.1f} km"

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=5512, reload=True)
