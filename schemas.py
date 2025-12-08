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
    phone_number: str
    full_name: str
    password: str


class UserLoginRequest(BaseModel):
    phone_number: str
    password: str


class UserResponse(BaseModel):
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
    success: bool
    message: str
    user: UserResponse
    token: str


# ============================================================================
# AI ANALYSIS SCHEMAS
# ============================================================================

class AIAnalysis(BaseModel):
    is_tree: bool
    is_real_photo: bool
    is_seedling: bool
    maturity: str
    health: str
    soil_moisture: str
    comment: str


# ============================================================================
# TASK SCHEMAS
# ============================================================================

class TaskSchema(BaseModel):
    id: str
    tree_id: str
    created_by_user_id: str
    assigned_user_id: Optional[str] = None
    type: str
    status: str
    due_date: datetime
    reward_points: int
    penalty_points: int = 0
    description: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None
    claimed_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


# ============================================================================
# CHECK-IN SCHEMAS
# ============================================================================

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


# ============================================================================
# NEARBY TASKS SCHEMAS
# ============================================================================

class NearbyTasksRequest(BaseModel):
    user_id: str
    latitude: float
    longitude: float


class NearbyTaskItem(BaseModel):
    task_id: str
    tree_id: str
    tree_owner_id: str
    tree_latitude: float
    tree_longitude: float
    type: str
    status: str
    due_date: datetime
    distance_meters: float
    reward_points: int
    penalty_points: int
    assigned_user_id: Optional[str] = None
    claimed_at: Optional[datetime] = None
    is_my_tree: bool


class NearbyTasksResponse(BaseModel):
    user_id: str
    now: str
    tasks: List[NearbyTaskItem]


class TaskClaimRequest(BaseModel):
    user_id: str
    task_id: str


class TaskClaimResponse(BaseModel):
    success: bool
    message: str
    task: TaskSchema


# ============================================================================
# MY TREES SCHEMAS
# ============================================================================

class TreeWithTasksItem(BaseModel):
    id: str
    latitude: float
    longitude: float
    centroid_lat: Optional[float] = None
    centroid_lon: Optional[float] = None
    segments: Optional[List[List[float]]] = None
    phase: str
    status: str
    last_health: Optional[str] = None
    last_soil_moisture: Optional[str] = None
    created_at: datetime
    pending_tasks: List[TaskSchema]
    completed_tasks: List[TaskSchema]


class MyTreesResponse(BaseModel):
    user_id: str
    trees: List[TreeWithTasksItem]


class TreeDetailResponse(BaseModel):
    tree: TreeWithTasksItem
    last_checkin: Optional[dict] = None
    total_checkins: int


# ============================================================================
# RATING SCHEMAS
# ============================================================================

class LeaderboardItem(BaseModel):
    user_id: str
    full_name: str
    avatar_url: Optional[str] = None
    task_count: int
    points_sum: int
    rank: int


class RatingResponse(BaseModel):
    range_type: str
    from_date: Optional[str] = None
    to_date: Optional[str] = None
    items: List[LeaderboardItem]


class UserStatsResponse(BaseModel):
    user_id: str
    total_points: int
    total_trees: int
    active_trees: int
    total_checkins: int
    pending_tasks: int
    completed_tasks: int
    claimed_tasks: int


# Bu yerga schemas.py ga qo'shish kerak bo'lgan qismlar

from typing import List, Optional, Dict, Any

# ... mavjud schemalar ...

# ============================================================================
# NEARBY SATELLITE TREES SCHEMAS
# ============================================================================

class NearbyTreesSearchRequest(BaseModel):
    """Request to search for nearby satellite trees"""
    latitude: float = Field(..., description="User's current latitude")
    longitude: float = Field(..., description="User's current longitude")
    radius_km: float = Field(2.0, description="Search radius in kilometers", ge=0.1, le=10.0)
    limit: int = Field(50, description="Maximum trees to return", ge=1, le=200)


class SatelliteTreeInfo(BaseModel):
    """Information about a satellite-detected tree"""
    tree_id: str
    class_name: str
    confidence: float
    centroid_lat: float
    centroid_lon: float
    segments: List[List[float]]
    distance_meters: float
    distance_km: float
    box: Dict[str, Any]


class NearbyTreesResponse(BaseModel):
    """Response with nearby satellite trees"""
    user_location: Dict[str, float]
    radius_km: float
    total_found: int
    trees: List[SatelliteTreeInfo]


class BoundingBoxRequest(BaseModel):
    """Request trees within a bounding box"""
    north: float = Field(..., description="Northern latitude")
    south: float = Field(..., description="Southern latitude")
    east: float = Field(..., description="Eastern longitude")
    west: float = Field(..., description="Western longitude")


class TreeDetailsResponse(BaseModel):
    """Detailed information about a specific tree"""
    tree_id: str
    class_name: str
    confidence: float
    centroid_lat: float
    centroid_lon: float
    segments: List[List[float]]
    box: Dict[str, Any]
    segment_count: int


class SatelliteTreesStatsResponse(BaseModel):
    """Statistics about satellite trees dataset"""
    total_trees: int
    avg_confidence: float
    min_confidence: float
    max_confidence: float
    avg_segments_per_tree: float
