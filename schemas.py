"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ============================================================================
# AUTH SCHEMAS
# ============================================================================

class UserRegisterRequest(BaseModel):
    """Ro'yxatdan o'tish uchun request"""
    phone_number: str = Field(..., description="Telefon raqami (+998901234567 formatida)")
    full_name: str = Field(..., min_length=2, max_length=100, description="To'liq ism")
    password: str = Field(..., min_length=6, description="Parol (kamida 6 ta belgi)")


class UserLoginRequest(BaseModel):
    """Login uchun request"""
    phone_number: str = Field(..., description="Telefon raqami")
    password: str = Field(..., description="Parol")


class UserResponse(BaseModel):
    """Foydalanuvchi ma'lumotlari response"""
    id: str
    phone_number: str
    full_name: str
    avatar_url: Optional[str] = None
    total_points: int
    is_active: bool
    is_verified: bool
    created_at: datetime
    last_login: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    """Autentifikatsiya muvaffaqiyatli bo'lganda response"""
    success: bool
    message: str
    user: UserResponse
    token: str  # JWT token yoki session token


# ============================================================================
# TREE & TASK SCHEMAS
# ============================================================================

class AIAnalysis(BaseModel):
    is_seedling: bool
    maturity: str  # seedling, young, mature, unknown
    health: str  # healthy, stressed, critical, unknown
    soil_moisture: str  # dry, normal, wet, unknown
    comment: str  # In Uzbek (Latin)


class TaskSchema(BaseModel):
    id: str
    tree_id: str
    type: str
    status: str
    due_date: datetime
    reward_points: int
    penalty_points: int = 0
    description: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class PointsSummary(BaseModel):
    awarded: int
    penalty: int
    total: int


class CheckInAnalysisResponse(BaseModel):
    status: str = "ANALYZED"
    accepted: bool
    cheat_suspected: bool = False
    error_code: Optional[str] = None
    message: Optional[str] = None
    tree_id: Optional[str] = None
    task_id: Optional[str] = None
    analysis: Optional[AIAnalysis] = None
    new_tasks: List[TaskSchema] = []
    updated_tasks: List[TaskSchema] = []
    points: PointsSummary


class UserTasksResponse(BaseModel):
    user_id: str
    total_points: int
    tasks: List[TaskSchema]


class TreeBasicInfo(BaseModel):
    id: str
    phase: str
    status: str
    last_health: Optional[str] = None
    last_soil_moisture: Optional[str] = None
    created_at: datetime
    latitude: float
    longitude: float
    successful_waterings: int
    
    class Config:
        from_attributes = True


class TreeDetailResponse(BaseModel):
    tree: TreeBasicInfo
    last_analysis: Optional[AIAnalysis] = None
    pending_tasks: List[TaskSchema]
    completed_tasks: List[TaskSchema]
    total_checkins: int


class UserStatsResponse(BaseModel):
    user_id: str
    total_points: int
    total_trees: int
    active_trees: int
    total_waterings: int
    total_checkins: int
    pending_tasks: int
    completed_tasks: int
