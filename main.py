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
    TreeDetailResponse,
    UserRegisterRequest,
    UserLoginRequest,
    AuthResponse,
    UserResponse
)
from services.checkin_service import CheckInService
from services.user_service import UserService
from services.tree_service import TreeService
from services.auth_service import AuthService

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


# ============================================================================
# AUTHENTICATION ENDPOINTS
# ============================================================================

@app.post("/api/v1/auth/register", response_model=AuthResponse)
async def register(
    request: UserRegisterRequest,
    db: Session = Depends(get_db)
):
    """
    Foydalanuvchini ro'yxatdan o'tkazish
    
    **Request body:**
    ```json
    {
        "phone_number": "+998901234567",
        "full_name": "Ali Valiyev",
        "password": "secret123"
    }
    ```
    
    **Success Response (200):**
    ```json
    {
        "success": true,
        "message": "Ro'yxatdan o'tish muvaffaqiyatli!",
        "user": {
            "id": "uuid-here",
            "phone_number": "+998901234567",
            "full_name": "Ali Valiyev",
            "avatar_url": null,
            "total_points": 0,
            "is_active": true,
            "is_verified": false,
            "created_at": "2025-12-06T10:00:00",
            "last_login": null
        },
        "token": "user-id:random-token"
    }
    ```
    
    **Error Response (400):**
    ```json
    {
        "success": false,
        "message": "Bu telefon raqami allaqachon ro'yxatdan o'tgan"
    }
    ```
    """
    auth_service = AuthService(db)
    
    success, message, user = await auth_service.register_user(
        phone_number=request.phone_number,
        full_name=request.full_name,
        password=request.password
    )
    
    if not success:
        raise HTTPException(status_code=400, detail=message)
    
    # Generate token
    token = auth_service._generate_token(user.id)
    
    return AuthResponse(
        success=True,
        message=message,
        user=UserResponse.from_orm(user),
        token=token
    )


@app.post("/api/v1/auth/login", response_model=AuthResponse)
async def login(
    request: UserLoginRequest,
    db: Session = Depends(get_db)
):
    """
    Foydalanuvchi tizimga kirishi
    
    **Request body:**
    ```json
    {
        "phone_number": "+998901234567",
        "password": "secret123"
    }
    ```
    
    **Success Response (200):**
    ```json
    {
        "success": true,
        "message": "Kirish muvaffaqiyatli!",
        "user": {
            "id": "uuid-here",
            "phone_number": "+998901234567",
            "full_name": "Ali Valiyev",
            "total_points": 150,
            "last_login": "2025-12-06T10:00:00"
        },
        "token": "user-id:random-token"
    }
    ```
    
    **Error Response (400):**
    ```json
    {
        "success": false,
        "message": "Telefon raqami yoki parol noto'g'ri"
    }
    ```
    """
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


@app.get("/api/v1/auth/me", response_model=UserResponse)
async def get_current_user(
    token: str,
    db: Session = Depends(get_db)
):
    """
    Joriy foydalanuvchi ma'lumotlarini olish (token orqali)
    
    **Query parameter:**
    - token: Authentication token
    
    **Success Response (200):**
    ```json
    {
        "id": "uuid-here",
        "phone_number": "+998901234567",
        "full_name": "Ali Valiyev",
        "total_points": 150,
        "is_active": true
    }
    ```
    
    **Error Response (401):**
    ```json
    {
        "detail": "Token noto'g'ri yoki muddati o'tgan"
    }
    ```
    """
    auth_service = AuthService(db)
    user = await auth_service.verify_token(token)
    
    if not user:
        raise HTTPException(status_code=401, detail="Token noto'g'ri yoki muddati o'tgan")
    
    return UserResponse.from_orm(user)


# ============================================================================
# TREE CHECK-IN ENDPOINTS
# ============================================================================


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
    Daraxt rasmini tahlil qilish va vazifalarni bajarish
    
    **Bu endpoint:**
    - Yangi ko'chat ekish (tree_id=null)
    - Sug'orish tekshiruvi (task_id bilan)
    - Holat monitoring (task_id bilan)
    
    **Form data:**
    - user_id: Foydalanuvchi ID (string)
    - tree_id: Daraxt ID (yangi ekish uchun null)
    - task_id: Vazifa ID (agar vazifa bajarilayotgan bo'lsa)
    - latitude: Kenglik (float)
    - longitude: Uzunlik (float)
    - client_timestamp: Vaqt (ISO8601)
    - phase_hint: Tur (planting, watering, monitoring)
    - image: Rasm fayli (JPEG/PNG)
    
    **YANGI KO'CHAT EKISH - Success Response (200):**
    ```json
    {
        "status": "ANALYZED",
        "accepted": true,
        "cheat_suspected": false,
        "tree_id": "new-tree-uuid",
        "analysis": {
            "is_seedling": true,
            "maturity": "seedling",
            "health": "healthy",
            "soil_moisture": "normal",
            "comment": "Ko'chat sog'lom, tuproq yaxshi holatda"
        },
        "new_tasks": [
            {
                "id": "task-uuid-1",
                "type": "watering",
                "due_date": "2025-12-07T00:00:00",
                "status": "pending",
                "reward_points": 30,
                "description": "Daraxtingizni sug'oring va rasmga oling"
            },
            {
                "id": "task-uuid-2",
                "type": "photo_check",
                "due_date": "2025-12-08T00:00:00",
                "status": "pending",
                "reward_points": 20
            }
        ],
        "updated_tasks": [],
        "points": {
            "awarded": 0,
            "penalty": 0,
            "total": 0
        }
    }
    ```
    
    **YANGI KO'CHAT EKISH - Rejected (200):**
    ```json
    {
        "status": "ANALYZED",
        "accepted": false,
        "error_code": "NOT_SEEDLING",
        "message": "Faqat yosh ko'chatlar qabul qilinadi",
        "analysis": {
            "is_seedling": false,
            "maturity": "mature",
            "comment": "Bu katta daraxt, ko'chat emas"
        },
        "points": {
            "awarded": 0,
            "penalty": 0,
            "total": 100
        }
    }
    ```
    
    **SUG'ORISH VAZIFASI - Success Response (200):**
    ```json
    {
        "status": "ANALYZED",
        "accepted": true,
        "tree_id": "existing-tree-uuid",
        "task_id": "task-uuid",
        "analysis": {
            "maturity": "seedling",
            "health": "healthy",
            "soil_moisture": "wet",
            "comment": "Sug'orish muvaffaqiyatli, tuproq nam"
        },
        "new_tasks": [
            {
                "id": "new-task-uuid",
                "type": "watering",
                "due_date": "2025-12-09T00:00:00",
                "reward_points": 30
            }
        ],
        "updated_tasks": [
            {
                "id": "task-uuid",
                "status": "completed",
                "reward_points": 30,
                "completed_at": "2025-12-06T10:00:00"
            }
        ],
        "points": {
            "awarded": 80,
            "penalty": 0,
            "total": 180
        }
    }
    ```
    
    **SUG'ORISH - Tuproq hali quruq (200):**
    ```json
    {
        "status": "ANALYZED",
        "accepted": false,
        "error_code": "LOW_MOISTURE",
        "message": "Tuproq hali ham quruq, qaytadan sug'oring",
        "analysis": {
            "soil_moisture": "dry",
            "comment": "Tuproq yetarlicha sug'orilmagan"
        },
        "points": {
            "awarded": 0,
            "penalty": 0,
            "total": 100
        }
    }
    ```
    
    **KECH BAJARILGAN VAZIFA (200):**
    ```json
    {
        "status": "ANALYZED",
        "accepted": false,
        "error_code": "TASK_LATE",
        "message": "Vazifa muddati o'tgan, -35 ball jarimasi",
        "updated_tasks": [
            {
                "id": "task-uuid",
                "status": "off",
                "penalty_points": -35
            }
        ],
        "points": {
            "awarded": 0,
            "penalty": -35,
            "total": 65
        }
    }
    ```
    
    **FIRIBGARLIK ANIQLANDI (200):**
    ```json
    {
        "status": "ANALYZED",
        "accepted": false,
        "cheat_suspected": true,
        "error_code": "DUPLICATE_TREE",
        "message": "Bu rasm allaqachon yuklangan",
        "points": {
            "awarded": 0,
            "penalty": 0,
            "total": 100
        }
    }
    ```
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
    Foydalanuvchining barcha vazifalarini olish
    
    **Query params:**
    - status: Vazifa holati (pending, completed, rejected, off)
    
    **Success Response (200):**
    ```json
    {
        "user_id": "user-uuid",
        "total_points": 250,
        "tasks": [
            {
                "id": "task-uuid-1",
                "tree_id": "tree-uuid",
                "type": "watering",
                "status": "pending",
                "due_date": "2025-12-07T00:00:00",
                "reward_points": 30,
                "penalty_points": 0,
                "description": "Daraxtingizni sug'oring",
                "created_at": "2025-12-06T10:00:00",
                "completed_at": null
            },
            {
                "id": "task-uuid-2",
                "type": "photo_check",
                "status": "completed",
                "reward_points": 20,
                "completed_at": "2025-12-05T15:30:00"
            }
        ]
    }
    ```
    
    **Faqat pending vazifalar:**
    GET `/api/v1/users/{user_id}/tasks?status=pending`
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
    Daraxt haqida batafsil ma'lumot olish
    
    **Success Response (200):**
    ```json
    {
        "tree": {
            "id": "tree-uuid",
            "phase": "seedling",
            "status": "active",
            "last_health": "healthy",
            "last_soil_moisture": "normal",
            "created_at": "2025-12-06T10:00:00",
            "latitude": 41.2995,
            "longitude": 69.2401,
            "successful_waterings": 2
        },
        "last_analysis": {
            "is_seedling": true,
            "maturity": "seedling",
            "health": "healthy",
            "soil_moisture": "normal",
            "comment": "Ko'chat yaxshi o'smoqda"
        },
        "pending_tasks": [
            {
                "id": "task-uuid",
                "type": "watering",
                "due_date": "2025-12-08T00:00:00",
                "reward_points": 30
            }
        ],
        "completed_tasks": [
            {
                "id": "task-uuid-old",
                "type": "photo_check",
                "status": "completed",
                "completed_at": "2025-12-05T10:00:00"
            }
        ],
        "total_checkins": 5
    }
    ```
    
    **Error Response (404):**
    ```json
    {
        "detail": "Tree not found"
    }
    ```
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
    Foydalanuvchining barcha daraxtlarini olish
    
    **Query params:**
    - status: Daraxt holati (active, dead, rejected)
    
    **Success Response (200):**
    ```json
    {
        "user_id": "user-uuid",
        "total_trees": 5,
        "trees": [
            {
                "id": "tree-uuid-1",
                "phase": "young",
                "status": "active",
                "last_health": "healthy",
                "created_at": "2025-11-01T10:00:00",
                "latitude": 41.2995,
                "longitude": 69.2401,
                "successful_waterings": 15
            },
            {
                "id": "tree-uuid-2",
                "phase": "seedling",
                "status": "active",
                "last_health": "stressed",
                "created_at": "2025-12-01T10:00:00",
                "successful_waterings": 3
            }
        ]
    }
    ```
    
    **Faqat faol daraxtlar:**
    GET `/api/v1/users/{user_id}/trees?status=active`
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
    Foydalanuvchi statistikasini olish
    
    **Success Response (200):**
    ```json
    {
        "user_id": "user-uuid",
        "total_points": 450,
        "total_trees": 8,
        "active_trees": 6,
        "total_waterings": 42,
        "total_checkins": 95,
        "pending_tasks": 5,
        "completed_tasks": 38
    }
    ```
    
    **Bu ma'lumotlar:**
    - total_points: Jami to'plangan ballar
    - total_trees: Jami ekilgan daraxtlar soni
    - active_trees: Faol (tirik) daraxtlar soni
    - total_waterings: Jami sug'orishlar soni
    - total_checkins: Jami yuklangan rasmlar soni
    - pending_tasks: Kutilayotgan vazifalar soni
    - completed_tasks: Bajarilgan vazifalar soni
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
