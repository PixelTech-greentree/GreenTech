import 'package:flutter/material.dart';
import 'api_service.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  // Location
  bool _locationGranted = false;
  double? _latitude;
  double? _longitude;

  bool get locationGranted => _locationGranted;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  // User data
  UserModel? _user;
  UserStatsModel? _stats;
  GlobalStatistics? _globalStats;
  List<TreeModel> _userTrees = [];
  List<TaskModel> _nearbyTasks = [];
  List<NearbyTreeModel> _nearbyTrees = [];
  List<RatingUserModel> _ratingUsers = [];

  UserModel? get user => _user;
  UserStatsModel? get stats => _stats;
  GlobalStatistics? get globalStats => _globalStats;
  List<TreeModel> get userTrees => _userTrees;
  List<TaskModel> get nearbyTasks => _nearbyTasks;
  List<NearbyTreeModel> get nearbyTrees => _nearbyTrees;
  List<RatingUserModel> get ratingUsers => _ratingUsers;

  bool get isLoggedIn => api.isLoggedIn;
  String? get userId => api.userId;

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setLocationGranted(bool granted) {
    _locationGranted = granted;
    notifyListeners();
  }

  void setLocation(double lat, double lng) {
    _latitude = lat;
    _longitude = lng;
    notifyListeners();
  }

  // ==================== AUTH ====================

  Future<ApiResult<UserModel>> login(String phone, String password) async {
    setLoading(true);
    final result = await api.login(phoneNumber: phone, password: password);
    if (result.success && result.data != null) {
      _user = result.data;
      await loadAllData();
    }
    setLoading(false);
    return result;
  }

  Future<ApiResult<UserModel>> register(String phone, String fullName, String password) async {
    setLoading(true);
    final result = await api.register(
      phoneNumber: phone,
      fullName: fullName,
      password: password,
    );
    if (result.success && result.data != null) {
      _user = result.data;
      await loadAllData();
    }
    setLoading(false);
    return result;
  }

  Future<void> logout() async {
    await api.logout();
    _user = null;
    _stats = null;
    _globalStats = null;
    _userTrees = [];
    _nearbyTasks = [];
    _nearbyTrees = [];
    _ratingUsers = [];
    _currentIndex = 0;
    notifyListeners();
  }

  Future<bool> checkAuth() async {
    if (!api.isLoggedIn) return false;

    final result = await api.getMe();
    if (result.success && result.data != null) {
      _user = result.data;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ==================== DATA LOADING ====================

  Future<void> loadAllData() async {
    await Future.wait([
      loadUser(),
      loadStats(),
      loadGlobalStats(),
      loadUserTrees(),
    ]);
  }

  Future<void> loadUser() async {
    final result = await api.getMe();
    if (result.success && result.data != null) {
      _user = result.data;
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    final result = await api.getUserStats();
    if (result.success && result.data != null) {
      _stats = result.data;
      notifyListeners();
    }
  }

  Future<void> loadGlobalStats() async {
    final result = await api.getGlobalStatistics();
    if (result.success && result.data != null) {
      _globalStats = result.data;
      notifyListeners();
    }
  }

  Future<void> loadUserTrees() async {
    final result = await api.getUserTreesDetailed();
    if (result.success && result.data != null) {
      _userTrees = result.data!;
      notifyListeners();
    }
  }

  Future<void> loadNearbyTasks() async {
    if (_latitude == null || _longitude == null) return;

    final result = await api.getNearbyTasksEnhanced(
      latitude: _latitude!,
      longitude: _longitude!,
    );
    if (result.success && result.data != null) {
      _nearbyTasks = result.data!;
      notifyListeners();
    }
  }

  Future<void> loadNearbyTrees() async {
    if (_latitude == null || _longitude == null) return;

    final result = await api.getNearbyTrees(
      latitude: _latitude!,
      longitude: _longitude!,
    );
    if (result.success && result.data != null) {
      _nearbyTrees = result.data!;
      notifyListeners();
    }
  }

  Future<void> loadRating({String period = '7days'}) async {
    final result = await api.getLeaderboard(period: period);
    if (result.success && result.data != null) {
      _ratingUsers = result.data!;
      notifyListeners();
    }
  }

  // ==================== ACTIONS ====================

  Future<ApiResult<ClaimResponse>> claimTask(String taskId) async {
    final result = await api.claimTaskEnhanced(taskId);
    if (result.success) {
      await loadNearbyTasks();
    }
    return result;
  }

  // ==================== GETTERS ====================

  int get totalPoints => _stats?.totalPoints ?? 0;
  int get totalTrees => _stats?.totalTrees ?? _userTrees.length;
  int get activeTrees => _stats?.activeTrees ?? 0;
  int get totalWaterings => _stats?.totalWaterings ?? 0;
  int get totalCheckins => _stats?.totalCheckins ?? 0;
  int get pendingTasks => _stats?.pendingTasks ?? 0;
  int get completedTasks => _stats?.completedTasks ?? 0;
  double get careScore => _stats?.careScore ?? 0;

  // Global stats
  int get globalTotalTrees => _globalStats?.totalTreesPlanted ?? 0;
  int get globalTotalUsers => _globalStats?.totalUsers ?? 0;
  int get globalActiveTrees => _globalStats?.totalActiveTrees ?? 0;

  String get userName => _user?.fullName ?? '';
  String get userPhone => _user?.phoneNumber ?? '';
  String get userCreatedAt => _user?.createdAt ?? '';
  String? get userAvatarUrl => _user?.avatarUrl;
}
