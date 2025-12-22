// ==================== HELPERS ====================

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

double? _parseDoubleNullable(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<String>? _parseStringList(dynamic value) {
  if (value == null) return null;
  if (value is List) return value.map((e) => e.toString()).toList();
  return null;
}

// ==================== USER ====================

class UserModel {
  final String id;
  final String phoneNumber;
  final String fullName;
  final String? avatarUrl;
  final String createdAt;
  final String? lastLogin;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    this.avatarUrl,
    required this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      phoneNumber: json['phone_number'] ?? '',
      fullName: json['full_name'] ?? '',
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'] ?? '',
      lastLogin: json['last_login'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone_number': phoneNumber,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'created_at': createdAt,
    'last_login': lastLogin,
  };
}

// ==================== USER STATS ====================

class UserStatsModel {
  final int totalPoints;
  final int totalTrees;
  final int activeTrees;
  final int totalWaterings;
  final int totalCheckins;
  final int pendingTasks;
  final int completedTasks;
  final int claimedTasks;
  final double careScore;

  UserStatsModel({
    required this.totalPoints,
    required this.totalTrees,
    required this.activeTrees,
    required this.totalWaterings,
    required this.totalCheckins,
    required this.pendingTasks,
    required this.completedTasks,
    required this.claimedTasks,
    this.careScore = 0,
  });

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      totalPoints: _parseInt(json['total_points']),
      totalTrees: _parseInt(json['total_trees']),
      activeTrees: _parseInt(json['active_trees']),
      totalWaterings: _parseInt(json['total_waterings']),
      totalCheckins: _parseInt(json['total_checkins']),
      pendingTasks: _parseInt(json['pending_tasks']),
      completedTasks: _parseInt(json['completed_tasks']),
      claimedTasks: _parseInt(json['claimed_tasks']),
      careScore: _parseDouble(json['care_score']),
    );
  }
}

// ==================== GLOBAL STATISTICS ====================

class GlobalStatistics {
  final int totalTreesPlanted;
  final int totalActiveTrees;
  final int totalUsers;
  final int totalTasksCompleted;
  final int totalWaterings;
  final double averageTreeHealth;
  final int recentPlantings7Days;
  final int recentPlantings30Days;

  GlobalStatistics({
    required this.totalTreesPlanted,
    required this.totalActiveTrees,
    required this.totalUsers,
    required this.totalTasksCompleted,
    required this.totalWaterings,
    required this.averageTreeHealth,
    required this.recentPlantings7Days,
    required this.recentPlantings30Days,
  });

  factory GlobalStatistics.fromJson(Map<String, dynamic> json) {
    final stats = json['statistics'] ?? json;
    return GlobalStatistics(
      totalTreesPlanted: _parseInt(stats['total_trees_planted']),
      totalActiveTrees: _parseInt(stats['total_active_trees']),
      totalUsers: _parseInt(stats['total_users']),
      totalTasksCompleted: _parseInt(stats['total_tasks_completed']),
      totalWaterings: _parseInt(stats['total_waterings']),
      averageTreeHealth: _parseDouble(stats['average_tree_health']),
      recentPlantings7Days: _parseInt(stats['recent_plantings_7days']),
      recentPlantings30Days: _parseInt(stats['recent_plantings_30days']),
    );
  }
}

// ==================== AI ANALYSIS ====================

class AIAnalysis {
  final String? health;
  final String? moisture;
  final DetailedAnalysis? detailedAnalysis;
  final Recommendations? recommendations;
  final String? comment;
  final bool? isTree;
  final bool? isRealPhoto;

  AIAnalysis({
    this.health,
    this.moisture,
    this.detailedAnalysis,
    this.recommendations,
    this.comment,
    this.isTree,
    this.isRealPhoto,
  });

  factory AIAnalysis.fromJson(Map<String, dynamic> json) {
    return AIAnalysis(
      health: json['health']?.toString(),
      moisture: json['moisture']?.toString() ?? json['soil_moisture']?.toString(),
      detailedAnalysis: json['detailed_analysis'] != null 
          ? DetailedAnalysis.fromJson(json['detailed_analysis']) 
          : null,
      recommendations: json['recommendations'] != null 
          ? Recommendations.fromJson(json['recommendations']) 
          : null,
      comment: json['comment']?.toString(),
      isTree: json['is_tree'],
      isRealPhoto: json['is_real_photo'],
    );
  }
}

class DetailedAnalysis {
  final String? plantType;
  final String? leafCondition;
  final List<String> problemsDetected;
  final List<String> positiveSigns;

  DetailedAnalysis({
    this.plantType,
    this.leafCondition,
    this.problemsDetected = const [],
    this.positiveSigns = const [],
  });

  factory DetailedAnalysis.fromJson(Map<String, dynamic> json) {
    return DetailedAnalysis(
      plantType: json['plant_type']?.toString(),
      leafCondition: json['leaf_condition']?.toString(),
      problemsDetected: _parseStringList(json['problems_detected']) ?? [],
      positiveSigns: _parseStringList(json['positive_signs']) ?? [],
    );
  }
}

class Recommendations {
  final List<String> immediateActions;
  final String? wateringSchedule;
  final List<String> nextSteps;

  Recommendations({
    this.immediateActions = const [],
    this.wateringSchedule,
    this.nextSteps = const [],
  });

  factory Recommendations.fromJson(Map<String, dynamic> json) {
    return Recommendations(
      immediateActions: _parseStringList(json['immediate_actions']) ?? [],
      wateringSchedule: json['watering_schedule']?.toString(),
      nextSteps: _parseStringList(json['next_steps']) ?? [],
    );
  }
}

// ==================== TREE (FULL) ====================

class TreeModel {
  final String id;
  final String? userId;
  final String? name;
  final String phase;
  final String status;
  final double latitude;
  final double longitude;
  final String createdAt;
  final String? plantedDateFormatted;
  final int daysOld;
  
  // Health
  final String? currentHealth;
  final String? currentMoisture;
  final String? healthTrend;
  final AIAnalysis? lastAiAnalysis;
  final String? lastAnalysisDate;
  
  // Photos
  final String? firstPhotoUrl;
  final String? latestPhotoUrl;
  final int totalPhotos;
  
  // Tasks
  final List<TaskModel> activeTasks;
  final int completedTasksCount;
  final int pendingTasksCount;
  
  // Stats
  final int totalWaterings;
  final int totalChecks;
  final double careScore;

  TreeModel({
    required this.id,
    this.userId,
    this.name,
    required this.phase,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.plantedDateFormatted,
    this.daysOld = 0,
    this.currentHealth,
    this.currentMoisture,
    this.healthTrend,
    this.lastAiAnalysis,
    this.lastAnalysisDate,
    this.firstPhotoUrl,
    this.latestPhotoUrl,
    this.totalPhotos = 0,
    this.activeTasks = const [],
    this.completedTasksCount = 0,
    this.pendingTasksCount = 0,
    this.totalWaterings = 0,
    this.totalChecks = 0,
    this.careScore = 0,
  });

  factory TreeModel.fromJson(Map<String, dynamic> json) {
    // Handle nested tree object
    final data = json['tree'] ?? json;
    
    return TreeModel(
      id: data['tree_id']?.toString() ?? data['id']?.toString() ?? '',
      userId: data['user_id']?.toString(),
      name: data['name'],
      phase: data['phase'] ?? data['maturity_level'] ?? 'seedling',
      status: data['status'] ?? 'active',
      latitude: _parseDouble(data['latitude'] ?? data['centroid_lat']),
      longitude: _parseDouble(data['longitude'] ?? data['centroid_lon']),
      createdAt: data['created_at'] ?? data['planted_date'] ?? '',
      plantedDateFormatted: data['planted_date_formatted'],
      daysOld: _parseInt(data['days_old'] ?? data['days_since_planting']),
      currentHealth: data['current_health']?.toString(),
      currentMoisture: data['current_moisture']?.toString(),
      healthTrend: data['health_trend']?.toString(),
      lastAiAnalysis: data['last_ai_analysis'] != null 
          ? AIAnalysis.fromJson(data['last_ai_analysis']) 
          : null,
      lastAnalysisDate: data['last_analysis_date'],
      firstPhotoUrl: data['first_photo_url'],
      latestPhotoUrl: data['latest_photo_url'],
      totalPhotos: _parseInt(data['total_photos']),
      activeTasks: (data['active_tasks'] as List?)
          ?.map((t) => TaskModel.fromJson(t))
          .toList() ?? [],
      completedTasksCount: _parseInt(data['completed_tasks_count']),
      pendingTasksCount: _parseInt(data['pending_tasks_count'] ?? (data['pending_tasks'] is int ? data['pending_tasks'] : 0)),
      totalWaterings: _parseInt(data['total_waterings']),
      totalChecks: _parseInt(data['total_checks']),
      careScore: _parseDouble(data['care_score']),
    );
  }
}

// ==================== TREE HEALTH HISTORY ====================

class HealthHistoryItem {
  final String date;
  final String? health;
  final String? moisture;
  final String? photoUrl;
  final String? aiComment;

  HealthHistoryItem({
    required this.date,
    this.health,
    this.moisture,
    this.photoUrl,
    this.aiComment,
  });

  factory HealthHistoryItem.fromJson(Map<String, dynamic> json) {
    return HealthHistoryItem(
      date: json['date'] ?? '',
      health: json['health']?.toString(),
      moisture: json['moisture']?.toString(),
      photoUrl: json['photo_url'],
      aiComment: json['ai_comment']?.toString(),
    );
  }
}

// ==================== TASK ====================

class TaskModel {
  final String id;
  final String treeId;
  final String type;
  final String status;
  final String? description;
  final String? dueDate;
  final String? dueDateFormatted;
  final String? timeRemaining;
  final bool isUrgent;
  final int rewardPoints;
  final int? penaltyPoints;
  final String? priority;
  final String? source;
  
  // Nearby task specific
  final String? treeOwnerName;
  final bool isOwnTree;
  final double? treeLatitude;
  final double? treeLongitude;
  final double? distanceMeters;
  final String? distanceFormatted;
  final bool canClaim;
  final String? claimedBy;
  final String? claimExpiresAt;
  final String? treeHealth;
  final String? treeMaturity;
  final bool requiresPhoto;

  TaskModel({
    required this.id,
    required this.treeId,
    required this.type,
    required this.status,
    this.description,
    this.dueDate,
    this.dueDateFormatted,
    this.timeRemaining,
    this.isUrgent = false,
    required this.rewardPoints,
    this.penaltyPoints,
    this.priority,
    this.source,
    this.treeOwnerName,
    this.isOwnTree = false,
    this.treeLatitude,
    this.treeLongitude,
    this.distanceMeters,
    this.distanceFormatted,
    this.canClaim = true,
    this.claimedBy,
    this.claimExpiresAt,
    this.treeHealth,
    this.treeMaturity,
    this.requiresPhoto = true,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['task_id']?.toString() ?? json['id']?.toString() ?? '',
      treeId: json['tree_id']?.toString() ?? '',
      type: json['type'] ?? json['task_type'] ?? '',
      status: json['status'] ?? json['current_status'] ?? 'pending',
      description: json['description'] ?? json['task_description'],
      dueDate: json['due_date'],
      dueDateFormatted: json['due_date_formatted'],
      timeRemaining: json['time_remaining'],
      isUrgent: json['is_urgent'] ?? false,
      rewardPoints: _parseInt(json['reward_points'] ?? json['points_reward'] ?? json['points']),
      penaltyPoints: json['penalty_points'] != null ? _parseInt(json['penalty_points']) : null,
      priority: json['priority']?.toString(),
      source: json['source']?.toString(),
      treeOwnerName: json['tree_owner_name'],
      isOwnTree: json['is_own_tree'] ?? json['is_my_tree'] ?? false,
      treeLatitude: _parseDoubleNullable(json['tree_latitude']),
      treeLongitude: _parseDoubleNullable(json['tree_longitude']),
      distanceMeters: _parseDoubleNullable(json['distance_meters']),
      distanceFormatted: json['distance_formatted'],
      canClaim: json['can_claim'] ?? true,
      claimedBy: json['claimed_by']?.toString(),
      claimExpiresAt: json['claim_expires_at'],
      treeHealth: json['tree_health']?.toString(),
      treeMaturity: json['tree_maturity']?.toString(),
      requiresPhoto: json['requires_photo'] ?? true,
    );
  }
  
  bool get isPending => status == 'pending';
  bool get isClaimed => status == 'claimed';
  bool get isCompleted => status == 'completed';
  bool get canBeClaimed => canClaim && status == 'pending' && claimedBy == null;
}

// ==================== TASK COMPLETION RESPONSE ====================

class TaskCompletionResponse {
  final bool success;
  final String message;
  final String taskId;
  final int pointsEarned;
  final int totalPoints;
  final AIAnalysis? aiFeedback;
  final List<TaskModel> nextTasks;

  TaskCompletionResponse({
    required this.success,
    required this.message,
    required this.taskId,
    required this.pointsEarned,
    required this.totalPoints,
    this.aiFeedback,
    this.nextTasks = const [],
  });

  factory TaskCompletionResponse.fromJson(Map<String, dynamic> json) {
    return TaskCompletionResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      taskId: json['task_id']?.toString() ?? '',
      pointsEarned: _parseInt(json['points_earned']),
      totalPoints: _parseInt(json['total_points']),
      aiFeedback: json['ai_feedback'] != null 
          ? AIAnalysis.fromJson(json['ai_feedback']) 
          : null,
      nextTasks: (json['next_tasks'] as List?)
          ?.map((t) => TaskModel.fromJson(t))
          .toList() ?? [],
    );
  }
}

// ==================== CLAIM RESPONSE ====================

class ClaimResponse {
  final bool success;
  final String message;
  final String? taskId;
  final String? expiresAt;
  final String? timeRemaining;

  ClaimResponse({
    required this.success,
    required this.message,
    this.taskId,
    this.expiresAt,
    this.timeRemaining,
  });

  factory ClaimResponse.fromJson(Map<String, dynamic> json) {
    return ClaimResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      taskId: json['task_id']?.toString(),
      expiresAt: json['expires_at'],
      timeRemaining: json['time_remaining'],
    );
  }
}

// ==================== NEARBY TREE (SATELLITE) ====================

class NearbyTreeModel {
  final String treeId;
  final double centroidLat;
  final double centroidLon;
  final double distanceMeters;
  final double confidence;
  final List<List<double>>? segments;

  NearbyTreeModel({
    required this.treeId,
    required this.centroidLat,
    required this.centroidLon,
    required this.distanceMeters,
    required this.confidence,
    this.segments,
  });

  factory NearbyTreeModel.fromJson(Map<String, dynamic> json) {
    return NearbyTreeModel(
      treeId: json['tree_id']?.toString() ?? '',
      centroidLat: _parseDouble(json['centroid_lat']),
      centroidLon: _parseDouble(json['centroid_lon']),
      distanceMeters: _parseDouble(json['distance_meters']),
      confidence: _parseDouble(json['confidence']),
      segments: _parseSegments(json['segments']),
    );
  }
  
  static List<List<double>>? _parseSegments(dynamic segments) {
    if (segments == null) return null;
    try {
      return (segments as List).map((s) => 
        (s as List).map((p) => _parseDouble(p)).toList()
      ).toList();
    } catch (e) {
      return null;
    }
  }
}

// ==================== RATING USER ====================

class RatingUserModel {
  final int rank;
  final String id;
  final String fullName;
  final String? avatarUrl;
  final int totalPoints;
  final int tasksCompleted;
  final int treesPlanted;
  final int activeTrees;
  final double careScore;
  final String? lastActivity;

  RatingUserModel({
    required this.rank,
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.totalPoints,
    required this.tasksCompleted,
    required this.treesPlanted,
    required this.activeTrees,
    required this.careScore,
    this.lastActivity,
  });

  factory RatingUserModel.fromJson(Map<String, dynamic> json) {
    return RatingUserModel(
      rank: _parseInt(json['rank']),
      id: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      avatarUrl: json['avatar_url'],
      totalPoints: _parseInt(json['total_points'] ?? json['points_sum']),
      tasksCompleted: _parseInt(json['tasks_completed'] ?? json['task_count']),
      treesPlanted: _parseInt(json['trees_planted']),
      activeTrees: _parseInt(json['active_trees']),
      careScore: _parseDouble(json['care_score']),
      lastActivity: json['last_activity'],
    );
  }
}

// ==================== CHECKIN RESPONSE (PLANTING) ====================

class CheckinResponse {
  final bool success;
  final bool accepted;
  final String? errorCode;
  final String? message;
  final String? treeId;
  final AIAnalysis? aiFeedback;
  final List<TaskModel> nextTasks;
  final int? pointsEarned;
  final int? totalPoints;

  CheckinResponse({
    required this.success,
    required this.accepted,
    this.errorCode,
    this.message,
    this.treeId,
    this.aiFeedback,
    this.nextTasks = const [],
    this.pointsEarned,
    this.totalPoints,
  });

  factory CheckinResponse.fromJson(Map<String, dynamic> json) {
    return CheckinResponse(
      success: json['success'] ?? (json['accepted'] ?? false),
      accepted: json['accepted'] ?? false,
      errorCode: json['error_code'],
      message: json['message'],
      treeId: json['tree_id']?.toString(),
      aiFeedback: json['ai_feedback'] != null 
          ? AIAnalysis.fromJson(json['ai_feedback']) 
          : (json['analysis'] != null ? AIAnalysis.fromJson(json['analysis']) : null),
      nextTasks: (json['next_tasks'] as List?)
          ?.map((t) => TaskModel.fromJson(t))
          .toList() ?? [],
      pointsEarned: json['points_earned'] != null ? _parseInt(json['points_earned']) : null,
      totalPoints: json['total_points'] != null ? _parseInt(json['total_points']) : null,
    );
  }
}
