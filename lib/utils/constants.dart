class AppConstants {
  // API URL
  static const String baseUrl = 'https://uyim24.uz:5512';
  
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_json';
  static const String userIdKey = 'user_id';
  
  // Static values
  static const int totalTreesUzbekistan = 250000000;
  static const int totalFundUzbekistan = 134000000;
  
  // Map defaults
  static const double defaultRadiusKm = 2.0;
  static const int defaultTreeLimit = 50;
  
  // Task claim timeout (30 minutes)
  static const int taskClaimTimeoutMinutes = 30;
}

class TaskTypes {
  static const String watering = 'watering';
  static const String photoCheck = 'photo_check';
  static const String closeupPhoto = 'closeup_photo';
  static const String cleanArea = 'clean_area';
  
  static String getName(String type) {
    switch (type) {
      case watering:
        return 'Sug\'orish';
      case photoCheck:
        return 'Holatni tekshirish';
      case closeupPhoto:
        return 'Yaqindan surat';
      case cleanArea:
        return 'Atrofni tozalash';
      default:
        return type;
    }
  }
  
  static String getIcon(String type) {
    switch (type) {
      case watering:
        return '💧';
      case photoCheck:
        return '📷';
      case closeupPhoto:
        return '🔍';
      case cleanArea:
        return '🧹';
      default:
        return '📋';
    }
  }
}

class TreePhases {
  static const String seedling = 'seedling';
  static const String young = 'young';
  static const String mature = 'mature';
  
  static String getName(String phase) {
    switch (phase) {
      case seedling:
        return 'Ko\'chat';
      case young:
        return 'Yosh daraxt';
      case mature:
        return 'Voyaga yetgan';
      default:
        return phase;
    }
  }
  
  static String getIcon(String phase) {
    switch (phase) {
      case seedling:
        return '🌱';
      case young:
        return '🌿';
      case mature:
        return '🌳';
      default:
        return '🌲';
    }
  }
}

class TaskStatus {
  static const String pending = 'pending';
  static const String claimed = 'claimed';
  static const String completed = 'completed';
  static const String off = 'off';
  static const String rejected = 'rejected';
}

class TreeStatus {
  static const String active = 'active';
  static const String dead = 'dead';
  static const String rejected = 'rejected';
}
