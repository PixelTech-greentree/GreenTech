"""
GreenTech Tree Seedling Tracking API
Main FastAPI application
"""
from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import Optional
import uuid
from datetime import datetime

from database import engine, get_db
from models import Base
from schemas import (
    CheckInAnalysisResponse,
    UserTasksResponse,
    TreeDetailResponse
)
from services.checkin_service import CheckInService
from services.user_service import UserService
from services.tree_service import TreeService

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="GreenTech Tree Tracking API",
    description="Backend API for mobile tree seedling tracking app",
    version="1.0.0"
)

# CORS middleware for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact mobile app origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": "GreenTech Tree Tracking API",
        "version": "1.0.0"
    }


@app.post("/api/v1/checkins/analyze", response_model=CheckInAnalysisResponse)
async def analyze_checkin(
    user_id: str = Form(...),
    tree_id: Optional[str] = Form(None),
    task_id: Optional[str] = Form(None),
    latitude: float = Form(...),
    longitude: float = Form(...),
    client_timestamp: str = Form(...),
    phase_hint: Optional[str] = Form(None),
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Main endpoint for analyzing tree check-ins.
    
    Handles:
    - New seedling plantings
    - Watering checks
    - Status monitoring
    - Anti-cheat validation
    - Task completion and generation
    - Points system
    """
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
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")


@app.get("/api/v1/users/{user_id}/tasks", response_model=UserTasksResponse)
async def get_user_tasks(
    user_id: str,
    status: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Get all tasks for a specific user.
    
    Query params:
    - status: filter by task status (pending, completed, rejected, off)
    """
    user_service = UserService(db)
    
    try:
        tasks = await user_service.get_user_tasks(user_id, status)
        user = await user_service.get_or_create_user(user_id)
        
        return UserTasksResponse(
            user_id=user_id,
            total_points=user.total_points,
            tasks=tasks
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/trees/{tree_id}", response_model=TreeDetailResponse)
async def get_tree_detail(
    tree_id: str,
    db: Session = Depends(get_db)
):
    """
    Get detailed information about a specific tree.
    
    Includes:
    - Tree basic info and current status
    - Last analysis data
    - All pending and completed tasks
    """
    tree_service = TreeService(db)
    
    try:
        tree_detail = await tree_service.get_tree_detail(tree_id)
        
        if not tree_detail:
            raise HTTPException(status_code=404, detail="Tree not found")
        
        return tree_detail
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/users/{user_id}/trees")
async def get_user_trees(
    user_id: str,
    status: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Get all trees planted by a user.
    
    Query params:
    - status: filter by tree status (active, dead, rejected)
    """
    tree_service = TreeService(db)
    
    try:
        trees = await tree_service.get_user_trees(user_id, status)
        return {
            "user_id": user_id,
            "total_trees": len(trees),
            "trees": trees
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/users/{user_id}/stats")
async def get_user_stats(
    user_id: str,
    db: Session = Depends(get_db)
):
    """
    Get user statistics and achievements.
    """
    user_service = UserService(db)
    
    try:
        stats = await user_service.get_user_stats(user_id)
        return stats
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
