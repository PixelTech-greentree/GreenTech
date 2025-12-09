import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  String? _token;
  String? _userId;

  String? get token => _token;
  String? get userId => _userId;
  bool get isLoggedIn => _token != null && _userId != null;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
    _userId = prefs.getString(AppConstants.userIdKey);
  }

  Future<void> _saveAuth(String token, String odeyId) async {
    _token = token;
    _userId = odeyId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userIdKey, odeyId);
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userKey);
  }

  // ==================== AUTH ====================

  Future<ApiResult<UserModel>> register({
    required String phoneNumber,
    required String fullName,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/v1/auth/register', data: {
        'phone_number': phoneNumber,
        'full_name': fullName,
        'password': password,
      });

      if (response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['user']);
        await _saveAuth(response.data['token'], user.id);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userKey, jsonEncode(response.data['user']));
        
        return ApiResult.success(user);
      }
      
      return ApiResult.error(response.data['message'] ?? 'Ro\'yxatdan o\'tishda xatolik');
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  Future<ApiResult<UserModel>> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'phone_number': phoneNumber,
        'password': password,
      });

      if (response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['user']);
        await _saveAuth(response.data['token'], user.id);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userKey, jsonEncode(response.data['user']));
        
        return ApiResult.success(user);
      }
      
      return ApiResult.error(response.data['message'] ?? 'Telefon raqami yoki parol noto\'g\'ri');
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  Future<ApiResult<UserModel>> getMe() async {
    if (_token == null) return ApiResult.error('Token topilmadi');

    try {
      final response = await _dio.get('/api/v1/auth/me', queryParameters: {'token': _token});
      
      final userData = response.data['user'] ?? response.data;
      final user = UserModel.fromJson(userData);
      return ApiResult.success(user);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        return ApiResult.error('Sessiya tugagan');
      }
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  // ==================== USERS ====================

  Future<ApiResult<UserStatsModel>> getUserStats() async {
    if (_userId == null) return ApiResult.error('Foydalanuvchi topilmadi');

    try {
      final response = await _dio.get('/api/v1/users/$_userId/stats');
      return ApiResult.success(UserStatsModel.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  Future<ApiResult<List<TreeModel>>> getUserTrees() async {
    if (_userId == null) return ApiResult.error('Foydalanuvchi topilmadi');

    try {
      final response = await _dio.get('/api/v1/users/$_userId/trees');
      final trees = (response.data['trees'] as List? ?? [])
          .map((t) => TreeModel.fromJson(t))
          .toList();
      return ApiResult.success(trees);
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  Future<ApiResult<List<TaskModel>>> getUserTasks({String? status}) async {
    if (_userId == null) return ApiResult.error('Foydalanuvchi topilmadi');

    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get('/api/v1/users/$_userId/tasks', queryParameters: queryParams);
      final tasks = (response.data['tasks'] as List? ?? [])
          .map((t) => TaskModel.fromJson(t))
          .toList();
      return ApiResult.success(tasks);
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  // ==================== TREES ====================

  Future<ApiResult<TreeModel>> getTreeDetails(String treeId) async {
    try {
      final response = await _dio.get('/api/v1/trees/$treeId');
      return ApiResult.success(TreeModel.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  Future<ApiResult<List<NearbyTreeModel>>> getNearbyTrees({
    required double latitude,
    required double longitude,
    double radiusKm = 2.0,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.post('/api/v1/trees/nearby', data: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        'limit': limit,
      });

      final trees = (response.data['trees'] as List? ?? [])
          .map((t) => NearbyTreeModel.fromJson(t))
          .toList();
      return ApiResult.success(trees);
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  // ==================== TASKS ====================

  Future<ApiResult<List<TaskModel>>> getNearbyTasks({
    required double latitude,
    required double longitude,
  }) async {
    if (_userId == null) return ApiResult.error('Foydalanuvchi topilmadi');

    try {
      final response = await _dio.post('/api/v1/tasks/nearby', data: {
        'user_id': _userId,
        'latitude': latitude,
        'longitude': longitude,
      });

      final tasks = (response.data['tasks'] as List? ?? [])
          .map((t) => TaskModel.fromJson(t))
          .toList();
      return ApiResult.success(tasks);
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  Future<ApiResult<TaskModel>> claimTask(String taskId) async {
    if (_userId == null) return ApiResult.error('Foydalanuvchi topilmadi');

    try {
      final response = await _dio.post('/api/v1/tasks/claim', data: {
        'task_id': taskId,
        'user_id': _userId,
      });

      return ApiResult.success(TaskModel.fromJson(response.data['task'] ?? response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  // ==================== CHECKINS ====================

  Future<ApiResult<CheckinResponse>> analyzeCheckin({
    String? treeId,
    String? taskId,
    required double latitude,
    required double longitude,
    required String phaseHint,
    required File imageFile,
  }) async {
    if (_userId == null) return ApiResult.error('Foydalanuvchi topilmadi');

    try {
      final formData = FormData.fromMap({
        'user_id': _userId,
        if (treeId != null) 'tree_id': treeId,
        if (taskId != null) 'task_id': taskId,
        'latitude': latitude,
        'longitude': longitude,
        'client_timestamp': DateTime.now().toUtc().toIso8601String(),
        'phase_hint': phaseHint,
        'image': await MultipartFile.fromFile(imageFile.path, filename: 'checkin.jpg'),
      });

      final response = await _dio.post('/api/v1/checkins/analyze', data: formData);
      return ApiResult.success(CheckinResponse.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  // ==================== RATING ====================

  Future<ApiResult<List<RatingUserModel>>> getRating({String range = '7d'}) async {
    try {
      final response = await _dio.get('/api/v1/users/rating', queryParameters: {'range': range});
      
      final users = (response.data['users'] as List? ?? response.data as List? ?? [])
          .map((u) => RatingUserModel.fromJson(u))
          .toList();
      return ApiResult.success(users);
    } on DioException catch (e) {
      return ApiResult.error(_handleDioError(e));
    } catch (e) {
      return ApiResult.error('Noma\'lum xatolik: $e');
    }
  }

  // ==================== HELPERS ====================

  String _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Internet bilan bog\'liq xato - ulanish vaqti tugadi';
    }
    
    if (e.type == DioExceptionType.connectionError) {
      return 'Internet bilan bog\'liq xato';
    }

    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map) {
        return data['detail'] ?? data['message'] ?? 'Server xatosi';
      }
      return 'Server xatosi: ${e.response?.statusCode}';
    }

    return 'Tarmoq xatosi';
  }
}

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult._({required this.success, this.data, this.error});

  factory ApiResult.success(T data) => ApiResult._(success: true, data: data);
  factory ApiResult.error(String message) => ApiResult._(success: false, error: message);
}

// Global instance
final api = ApiService();
