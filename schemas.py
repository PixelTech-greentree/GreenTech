"""
Pydantic schemas for request/response validation
Complete version with combined trees (DB + Satellite) support
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
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


# ============================================================================
# COMBINED NEARBY TREES SCHEMAS (DB + SATELLITE)
# ============================================================================

class NearbyTreesSearchRequest(BaseModel):
    """Request to search for nearby trees"""
    latitude: float = Field(..., description="User's current latitude")
    longitude: float = Field(..., description="User's current longitude")
    radius_km: float = Field(2.0, description="Search radius in kilometers", ge=0.1, le=10.0)
    limit: int = Field(50, description="Maximum trees to return", ge=1, le=200)


class SatelliteTreeInfo(BaseModel):
    """Satellite-detected tree information"""
    tree_id: str
    source: str = "satellite"
    class_name: str
    confidence: float
    centroid_lat: float
    centroid_lon: float
    segments: List[List[float]]
    distance_meters: float
    distance_km: float
    box: Dict[str, Any]


class UserPlantedTreeInfo(BaseModel):
    """User-planted tree information from database"""
    tree_id: str
    source: str = "user_planted"
    user_id: str
    phase: str
    status: str
    health: Optional[str] = None
    soil_moisture: Optional[str] = None
    centroid_lat: float
    centroid_lon: float
    segments: List[List[float]] = []
    distance_meters: float
    distance_km: float
    created_at: Optional[str] = None


class CombinedTreeInfo(BaseModel):
    """Combined tree info that can be either satellite or user-planted"""
    tree_id: str
    source: str  # "satellite" or "user_planted"
    centroid_lat: float
    centroid_lon: float
    distance_meters: float
    distance_km: float
    segments: List[List[float]] = []
    
    # Satellite-specific fields (optional)
    class_name: Optional[str] = None
    confidence: Optional[float] = None
    box: Optional[Dict[str, Any]] = None
    
    # User-planted specific fields (optional)
    user_id: Optional[str] = None
    phase: Optional[str] = None
    status: Optional[str] = None
    health: Optional[str] = None
    soil_moisture: Optional[str] = None
    created_at: Optional[str] = None


class NearbyTreesResponse(BaseModel):
    """Response with nearby trees from both sources"""
    user_location: Dict[str, float]
    radius_km: float
    total_found: int
    trees: List[Union[SatelliteTreeInfo, UserPlantedTreeInfo, Dict[str, Any]]]


class BoundingBoxRequest(BaseModel):
    """Request trees within a bounding box"""
    north: float = Field(..., description="Northern latitude boundary")
    south: float = Field(..., description="Southern latitude boundary")
    east: float = Field(..., description="Eastern longitude boundary")
    west: float = Field(..., description="Western longitude boundary")


class TreeDetailsResponse(BaseModel):
    """Detailed information about a specific tree (satellite or user-planted)"""
    tree_id: str
    source: str  # "satellite" or "user_planted"
    centroid_lat: float
    centroid_lon: float
    segments: List[List[float]]
    
    # Satellite-specific fields
    class_name: Optional[str] = None
    confidence: Optional[float] = None
    box: Optional[Dict[str, Any]] = None
    segment_count: Optional[int] = None
    
    # User-planted specific fields
    user_id: Optional[str] = None
    phase: Optional[str] = None
    status: Optional[str] = None
    health: Optional[str] = None
    soil_moisture: Optional[str] = None
    created_at: Optional[str] = None


class SatelliteTreesStatsResponse(BaseModel):
    """Statistics about satellite trees dataset only"""
    total_trees: int
    avg_confidence: float
    min_confidence: float
    max_confidence: float
    avg_segments_per_tree: Optional[float] = None


class CombinedTreesStatsResponse(BaseModel):
    """Statistics about all trees (satellite + user-planted)"""
    satellite_trees: int
    user_planted_trees: int
    total_trees: int
    satellite_avg_confidence: Optional[float] = None
    satellite_min_confidence: Optional[float] = None
    satellite_max_confidence: Optional[float] = None


# ============================================================================
# STANDARD API RESPONSES
# ============================================================================

class SuccessResponse(BaseModel):
    """Standard success response"""
    success: bool = True
    message: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class ErrorResponse(BaseModel):
    """Standard error response"""
    success: bool = False
    error: str
    error_code: Optional[str] = None
    details: Optional[Dict[str, Any]] = None



# schemas.py ga QO'SHIMCHA QILINADIGAN MODELLAR
# Mavjud schemalar ustiga qo'shing

from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime


# ============================================================================
# ENHANCED AI ANALYSIS SCHEMAS
# ============================================================================

class DetailedPlantAnalysis(BaseModel):
    """Batafsil o'simlik tahlili"""
    plant_type: str
    leaf_condition: str
    stem_condition: str
    soil_condition: str
    problems_detected: List[str] = []
    positive_signs: List[str] = []


class PlantRecommendations(BaseModel):
    """Parvarish tavsifalari"""
    immediate_actions: List[str] = []
    watering_schedule: str
    lighting_needs: str
    next_steps: List[str] = []
    warnings: List[str] = []


class ComparisonAnalysis(BaseModel):
    """Taqqoslash tahlili"""
    health_change: str  # improved, worsened, stable
    growth_detected: bool
    moisture_change: str  # increased, decreased, stable
    new_problems: List[str] = []
    improvements: List[str] = []
    overall_trend: str  # positive, negative, neutral


class DetailedChanges(BaseModel):
    """Batafsil o'zgarishlar"""
    leaves: str
    stem: str
    soil: str
    environment: str


class ChangeRecommendations(BaseModel):
    """O'zgarish bo'yicha tavsiyalar"""
    continue_actions: List[str] = []
    new_actions: List[str] = []
    warnings: List[str] = []


class EnhancedAIAnalysis(BaseModel):
    """Kengaytirilgan AI tahlili"""
    is_tree: bool
    is_real_photo: bool
    is_seedling: bool
    maturity: str
    health: str
    soil_moisture: str
    detailed_analysis: DetailedPlantAnalysis
    recommendations: PlantRecommendations
    comment: str


class EnhancedComparisonAnalysis(BaseModel):
    """Kengaytirilgan solishtirish tahlili"""
    is_tree: bool
    is_real_photo: bool
    is_seedling: bool
    same_scene: bool
    maturity: str
    health: str
    soil_moisture: str
    comparison: ComparisonAnalysis
    detailed_changes: DetailedChanges
    recommendations: ChangeRecommendations
    changes: str
    comment: str


# ============================================================================
# TREE HEALTH STATUS SCHEMAS
# ============================================================================

class TreeHealthStatus(BaseModel):
    """Daraxt salomatligi holati"""
    tree_id: str
    current_health: str
    current_moisture: str
    last_check_date: Optional[datetime]
    days_since_planting: int
    maturity_level: str
    status: str  # active, needs_attention, critical
    health_trend: str  # improving, stable, declining, unknown
    last_ai_analysis: Optional[EnhancedAIAnalysis] = None


class TreeHealthHistoryItem(BaseModel):
    """Salomatlik tarixi elementi"""
    date: datetime
    health: str
    moisture: str
    photo_url: Optional[str] = None
    ai_comment: str


class TreeHealthHistoryResponse(BaseModel):
    """Salomatlik tarixi javobi"""
    tree_id: str
    current_status: TreeHealthStatus
    history: List[TreeHealthHistoryItem]
    total_checks: int


# ============================================================================
# ENHANCED TREE DETAIL SCHEMAS
# ============================================================================

class AIGeneratedTask(BaseModel):
    """AI tomonidan yaratilgan vazifa"""
    type: str
    due_date: str  # Odam tushunadigan format
    due_date_iso: datetime
    description: str
    points: int
    priority: str
    status: str
    source: str = "greenify_ai"


class EnhancedTreeDetail(BaseModel):
    """Kengaytirilgan daraxt tafsilotlari"""
    tree_id: str
    user_id: str
    planted_date: datetime
    planted_date_formatted: str  # "15 yanvar, 2024"
    days_old: int
    
    # Location
    latitude: float
    longitude: float
    centroid_lat: Optional[float]
    centroid_lon: Optional[float]
    segments: List[List[float]] = []
    
    # Current status
    phase: str
    status: str
    maturity: str
    current_health: str
    current_moisture: str
    health_trend: str
    
    # Photos
    first_photo_url: Optional[str] = None
    latest_photo_url: Optional[str] = None
    total_photos: int
    
    # AI Analysis
    last_ai_analysis: Optional[EnhancedAIAnalysis] = None
    last_analysis_date: Optional[datetime] = None
    
    # Tasks
    active_tasks: List[AIGeneratedTask]
    completed_tasks_count: int
    pending_tasks_count: int
    
    # Statistics
    total_waterings: int
    total_checks: int
    care_score: int  # 0-100


# ============================================================================
# TASK COMPLETION WITH IMAGE SCHEMAS
# ============================================================================

class TaskCompletionRequest(BaseModel):
    """Vazifa bajarish so'rovi (rasm bilan)"""
    user_id: str
    task_id: str
    latitude: float
    longitude: float
    client_timestamp: str


class TaskCompletionResponse(BaseModel):
    """Vazifa bajarish javobi"""
    success: bool
    message: str
    task_id: str
    points_earned: int
    total_points: int
    ai_feedback: Optional[EnhancedAIAnalysis] = None
    next_tasks: List[AIGeneratedTask] = []


# ============================================================================
# RATING SCHEMAS (ENHANCED)
# ============================================================================

class EnhancedLeaderboardItem(BaseModel):
    """Kengaytirilgan lider taxtasi elementi"""
    rank: int
    user_id: str
    full_name: str
    avatar_url: Optional[str] = None
    total_points: int
    tasks_completed: int
    trees_planted: int
    active_trees: int
    care_score: float  # O'rtacha g'amxo'rlik bahosi
    last_activity: Optional[datetime] = None


class LeaderboardResponse(BaseModel):
    """Lider taxtasi javobi"""
    period: str  # "7kun", "30kun", "Barcha vaqt"
    period_start: Optional[datetime] = None
    period_end: datetime
    total_users: int
    leaders: List[EnhancedLeaderboardItem]


# ============================================================================
# STATISTICS SCHEMAS
# ============================================================================

class GlobalStatisticsResponse(BaseModel):
    """Global statistika"""
    total_trees_planted: int
    total_active_trees: int
    total_users: int
    total_tasks_completed: int
    total_waterings: int
    average_tree_health: float
    trees_by_status: Dict[str, int]
    trees_by_maturity: Dict[str, int]
    recent_plantings_7days: int
    recent_plantings_30days: int


# ============================================================================
# NEARBY TASKS (ENHANCED)
# ============================================================================

class EnhancedNearbyTaskItem(BaseModel):
    """Kengaytirilgan yaqin vazifa"""
    task_id: str
    tree_id: str
    tree_owner_name: str
    task_type: str
    task_description: str
    priority: str
    due_date: datetime
    due_date_formatted: str  # "Bugun 18:00" yoki "Ertaga" yoki "3 kun ichida"
    time_remaining: str  # "2 soat 15 daqiqa"
    is_urgent: bool
    
    # Location
    tree_latitude: float
    tree_longitude: float
    distance_meters: float
    distance_formatted: str  # "120 metr" yoki "1.5 km"
    
    # Rewards
    points_reward: int
    current_status: str
    can_claim: bool
    claimed_by: Optional[str] = None
    claim_expires_at: Optional[datetime] = None
    
    # Tree info
    tree_health: str
    tree_maturity: str
    requires_photo: bool = True
