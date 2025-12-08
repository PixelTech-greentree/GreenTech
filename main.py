"""
GreenTech Backend - Complete System with Nearby Trees
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
    version="5.0.0",
    description="Full backend with nearby satellite trees feature",
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

# Initialize Nearby Trees Service (global)
nearby_trees_service = NearbyTreesService("cords_tree.json")


@app.on_event("startup")
async def startup():
    """Initialize database and load satellite trees"""
    await init_db()
    print("✅ Database initialized on port 5512")
    
    stats = nearby_trees_service.get_statistics()
    print(f"✅ Loaded {stats['total_trees']} satellite trees")


@app.get("/")
async def root():
    return {
        "status": "ok",
        "service": "GreenTech Complete API",
        "version": "5.0.0",
        "port": 5512,
        "features": ["auth", "checkins", "tasks", "rating", "nearby_trees"]
    }


# ============================================================================
# AUTHENTICATION (mavjud kodlar)
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
# CHECK-IN (mavjud kodlar)
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
# NEARBY SATELLITE TREES (YANGI!)
# ============================================================================

@app.post("/api/v1/trees/nearby", response_model=NearbyTreesResponse, tags=["Satellite Trees"])
async def get_nearby_satellite_trees(
    request: NearbyTreesSearchRequest
):
    """
    Get satellite-detected trees near user's location
    
    - **latitude**: User's current latitude
    - **longitude**: User's current longitude
    - **radius_km**: Search radius in kilometers (default: 2.0, max: 10.0)
    - **limit**: Maximum number of trees to return (default: 50, max: 200)
    """
    try:
        trees = nearby_trees_service.get_nearby_trees(
            user_lat=request.latitude,
            user_lon=request.longitude,
            radius_km=request.radius_km,
            limit=request.limit
        )
        
        return NearbyTreesResponse(
            user_location={
                "latitude": request.latitude,
                "longitude": request.longitude
            },
            radius_km=request.radius_km,
            total_found=len(trees),
            trees=[SatelliteTreeInfo(**tree) for tree in trees]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/trees/satellite/{tree_id}", response_model=TreeDetailsResponse, tags=["Satellite Trees"])
async def get_satellite_tree_details(tree_id: str):
    """
    Get detailed information about a specific satellite tree
    
    - **tree_id**: Satellite tree identifier (e.g., sat_0_1234)
    """
    tree_details = nearby_trees_service.get_tree_details(tree_id)
    
    if not tree_details:
        raise HTTPException(status_code=404, detail="Satellite tree not found")
    
    return TreeDetailsResponse(**tree_details)


@app.post("/api/v1/trees/bounds", tags=["Satellite Trees"])
async def get_trees_in_bounds(request: BoundingBoxRequest):
    """
    Get all satellite trees within a bounding box
    
    - **north**: Northern latitude boundary
    - **south**: Southern latitude boundary  
    - **east**: Eastern longitude boundary
    - **west**: Western longitude boundary
    """
    try:
        trees = nearby_trees_service.get_trees_in_bounds(
            north=request.north,
            south=request.south,
            east=request.east,
            west=request.west
        )
        
        return {
            "bounds": {
                "north": request.north,
                "south": request.south,
                "east": request.east,
                "west": request.west
            },
            "total_found": len(trees),
            "trees": trees
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/trees/satellite/stats", response_model=SatelliteTreesStatsResponse, tags=["Satellite Trees"])
async def get_satellite_trees_stats():
    """
    Get statistics about the loaded satellite trees dataset
    """
    stats = nearby_trees_service.get_statistics()
    return SatelliteTreesStatsResponse(**stats)


# ============================================================================
# NEARBY TASKS (mavjud kodlar)
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
# MY TREES (mavjud kodlar)
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
# RATING (mavjud kodlar)
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


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=5512, reload=True)
