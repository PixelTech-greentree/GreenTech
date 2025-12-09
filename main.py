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


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=5512, reload=True)
