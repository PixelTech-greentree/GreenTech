// User Model
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
      id: json['id']?.toString() ?? '',
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

// User Stats Model
class UserStatsModel {
  final int totalPoints;
  final int totalTrees;
  final int activeTrees;
  final int totalWaterings;
  final int totalCheckins;
  final int pendingTasks;
  final int completedTasks;
  final int claimedTasks;

  UserStatsModel({
    required this.totalPoints,
    required this.totalTrees,
    required this.activeTrees,
    required this.totalWaterings,
    required this.totalCheckins,
    required this.pendingTasks,
    required this.completedTasks,
    required this.claimedTasks,
  });

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      totalPoints: json['total_points'] ?? 0,
      totalTrees: json['total_trees'] ?? 0,
      activeTrees: json['active_trees'] ?? 0,
      totalWaterings: json['total_waterings'] ?? 0,
      totalCheckins: json['total_checkins'] ?? 0,
      pendingTasks: json['pending_tasks'] ?? 0,
      completedTasks: json['completed_tasks'] ?? 0,
      claimedTasks: json['claimed_tasks'] ?? 0,
    );
  }
}

// Tree Model
class TreeModel {
  final String id;
  final String? name;
  final String phase;
  final String status;
  final double latitude;
  final double longitude;
  final String createdAt;
  final double? lastHealth;
  final double? lastSoilMoisture;
  final int pendingTasksCount;
  final List<TaskModel> pendingTasks;
  final List<TaskModel> completedTasks;

  TreeModel({
    required this.id,
    this.name,
    required this.phase,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.lastHealth,
    this.lastSoilMoisture,
    this.pendingTasksCount = 0,
    this.pendingTasks = const [],
    this.completedTasks = const [],
  });

  factory TreeModel.fromJson(Map<String, dynamic> json) {
    return TreeModel(
      id: json['id']?.toString() ?? json['tree_id']?.toString() ?? '',
      name: json['name'],
      phase: json['phase'] ?? 'seedling',
      status: json['status'] ?? 'active',
      latitude: _parseDouble(json['latitude'] ?? json['centroid_lat']),
      longitude: _parseDouble(json['longitude'] ?? json['centroid_lon']),
      createdAt: json['created_at'] ?? '',
      lastHealth: _parseDoubleNullable(json['last_health']),
      lastSoilMoisture: _parseDoubleNullable(json['last_soil_moisture']),
      pendingTasksCount: json['pending_tasks_count'] ?? (json['pending_tasks'] as List?)?.length ?? 0,
      pendingTasks: (json['pending_tasks'] as List?)?.map((t) => TaskModel.fromJson(t)).toList() ?? [],
      completedTasks: (json['completed_tasks'] as List?)?.map((t) => TaskModel.fromJson(t)).toList() ?? [],
    );
  }
  
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

// Task Model
class TaskModel {
  final String id;
  final String treeId;
  final String type;
  final String status;
  final String? dueDate;
  final int rewardPoints;
  final int? penaltyPoints;
  final String? assignedUserId;
  final String? claimedAt;
  final double? distanceMeters;
  final bool isMyTree;

  TaskModel({
    required this.id,
    required this.treeId,
    required this.type,
    required this.status,
    this.dueDate,
    required this.rewardPoints,
    this.penaltyPoints,
    this.assignedUserId,
    this.claimedAt,
    this.distanceMeters,
    this.isMyTree = false,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? json['task_id']?.toString() ?? '',
      treeId: json['tree_id']?.toString() ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'pending',
      dueDate: json['due_date'],
      rewardPoints: _parseInt(json['reward_points']),
      penaltyPoints: json['penalty_points'] != null ? _parseInt(json['penalty_points']) : null,
      assignedUserId: json['assigned_user_id']?.toString(),
      claimedAt: json['claimed_at'],
      distanceMeters: _parseDoubleNullable(json['distance_meters']),
      isMyTree: json['is_my_tree'] ?? false,
    );
  }
  
  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  bool get canBeClaimed => status == 'pending' && assignedUserId == null;
  bool get isClaimed => status == 'claimed';
  bool get isCompleted => status == 'completed';
}

// Nearby Tree (Satellite) Model
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
  
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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

// Rating User Model
class RatingUserModel {
  final String id;
  final String fullName;
  final int taskCount;
  final int pointsSum;
  final int rank;

  RatingUserModel({
    required this.id,
    required this.fullName,
    required this.taskCount,
    required this.pointsSum,
    required this.rank,
  });

  factory RatingUserModel.fromJson(Map<String, dynamic> json) {
    return RatingUserModel(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      taskCount: json['task_count'] ?? 0,
      pointsSum: json['points_sum'] ?? 0,
      rank: json['rank'] ?? 0,
    );
  }
}

// Checkin Analysis Response
class CheckinResponse {
  final String status;
  final bool accepted;
  final String? errorCode;
  final String? message;
  final String? treeId;
  final AnalysisResult? analysis;
  final List<TaskModel>? newTasks;
  final PointsInfo? points;

  CheckinResponse({
    required this.status,
    required this.accepted,
    this.errorCode,
    this.message,
    this.treeId,
    this.analysis,
    this.newTasks,
    this.points,
  });

  factory CheckinResponse.fromJson(Map<String, dynamic> json) {
    return CheckinResponse(
      status: json['status'] ?? '',
      accepted: json['accepted'] ?? false,
      errorCode: json['error_code'],
      message: json['message'],
      treeId: json['tree_id']?.toString(),
      analysis: json['analysis'] != null ? AnalysisResult.fromJson(json['analysis']) : null,
      newTasks: (json['new_tasks'] as List?)?.map((t) => TaskModel.fromJson(t)).toList(),
      points: json['points'] != null ? PointsInfo.fromJson(json['points']) : null,
    );
  }
}

class AnalysisResult {
  final String? comment;
  final List<String>? recommendations;
  final double? healthScore;
  final double? soilMoisture;

  AnalysisResult({
    this.comment,
    this.recommendations,
    this.healthScore,
    this.soilMoisture,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      comment: json['comment']?.toString(),
      recommendations: _parseStringList(json['recommendations']),
      healthScore: _parseDoubleNullable(json['health_score']),
      soilMoisture: _parseDoubleNullable(json['soil_moisture']),
    );
  }
  
  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }
  
  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class PointsInfo {
  final int awarded;
  final int total;

  PointsInfo({required this.awarded, required this.total});

  factory PointsInfo.fromJson(Map<String, dynamic> json) {
    return PointsInfo(
      awarded: _parseInt(json['awarded']),
      total: _parseInt(json['total']),
    );
  }
  
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
