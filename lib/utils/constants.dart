class AppConstants {
  // API URL
  static const String baseUrl = 'https://uyim24.uz:5512';
  
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_json';
  static const String userIdKey = 'user_id';
  
  // Task claim timeout (30 minutes)
  static const int taskClaimTimeoutMinutes = 30;
}

class TaskTypes {
  static const String watering = 'watering';
  static const String photoCheck = 'photo_check';
  static const String closeupPhoto = 'closeup_photo';
  static const String cleanArea = 'clean_area';
  static const String fertilizing = 'fertilizing';
  static const String pruning = 'pruning';
  static const String pestCheck = 'pest_check';
  
  static String getName(String type) {
    switch (type) {
      case watering: return 'Sug\'orish';
      case photoCheck: return 'Holatni tekshirish';
      case closeupPhoto: return 'Yaqindan surat';
      case cleanArea: return 'Atrofni tozalash';
      case fertilizing: return 'O\'g\'itlash';
      case pruning: return 'Budama';
      case pestCheck: return 'Zararkunandalar tekshiruvi';
      default: return type;
    }
  }
  
  static String getIcon(String type) {
    switch (type) {
      case watering: return '💧';
      case photoCheck: return '📷';
      case closeupPhoto: return '🔍';
      case cleanArea: return '🧹';
      case fertilizing: return '🌿';
      case pruning: return '✂️';
      case pestCheck: return '🐛';
      default: return '📋';
    }
  }
}

class TreePhases {
  static const String seedling = 'seedling';
  static const String young = 'young';
  static const String mature = 'mature';
  
  static String getName(String phase) {
    switch (phase) {
      case seedling: return 'Ko\'chat';
      case young: return 'Yosh daraxt';
      case mature: return 'Voyaga yetgan';
      default: return phase;
    }
  }
  
  static String getIcon(String phase) {
    switch (phase) {
      case seedling: return '🌱';
      case young: return '🌿';
      case mature: return '🌳';
      default: return '🌲';
    }
  }
}
