import 'package:flutter/material.dart';

class TaskModel {
  final String id;
  final String name;
  bool isCompleted;

  TaskModel({required this.id, required this.name, required this.isCompleted});
}

class TreeModel {
  final String id;
  final String name;
  final String location;
  final List<TaskModel> tasks;

  TreeModel({required this.id, required this.name, required this.location, required this.tasks});
  
  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  int get totalTasks => tasks.length;
  double get progress => totalTasks > 0 ? completedTasks / totalTasks : 0;
}

class UserModel {
  final String username;
  final String fullName;
  final String phone;
  final int tasksCompletedToday;
  final int totalPoints;
  final List<String> promoCodes;
  final List<String> badges;
  final int treesPlanted;

  UserModel({
    required this.username,
    required this.fullName,
    required this.phone,
    required this.tasksCompletedToday,
    required this.totalPoints,
    required this.promoCodes,
    required this.badges,
    required this.treesPlanted,
  });
}

class AppState extends ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  
  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }
  
  bool _locationGranted = false;
  bool get locationGranted => _locationGranted;
  
  void setLocationGranted(bool granted) {
    _locationGranted = granted;
    notifyListeners();
  }
  
  final int _totalTrees = 12847;
  final int _totalMembers = 3421;
  final int _totalFunds = 847500000;
  
  int get totalTrees => _totalTrees;
  int get totalMembers => _totalMembers;
  int get totalFunds => _totalFunds;
  
  List<TreeModel> _userTrees = [];
  List<TreeModel> get userTrees => _userTrees;
  
  void loadUserTrees() {
    _userTrees = [
      TreeModel(
        id: '1',
        name: 'Eman daraxti #127',
        location: 'Toshkent Markaziy Bog\'i',
        tasks: [
          TaskModel(id: '1', name: 'Sug\'orish', isCompleted: true),
          TaskModel(id: '2', name: 'O\'g\'itlash', isCompleted: false),
          TaskModel(id: '3', name: 'Sog\'ligini tekshirish', isCompleted: false),
        ],
      ),
      TreeModel(
        id: '2',
        name: 'Qarag\'ay #89',
        location: 'Chilonzor tumani',
        tasks: [
          TaskModel(id: '4', name: 'Sug\'orish', isCompleted: true),
          TaskModel(id: '5', name: 'Shoxlarni kesish', isCompleted: true),
          TaskModel(id: '6', name: 'Tuproq qo\'shish', isCompleted: false),
        ],
      ),
      TreeModel(
        id: '3',
        name: 'Zarang daraxti #203',
        location: 'Sergeli tumani',
        tasks: [
          TaskModel(id: '7', name: 'Sug\'orish', isCompleted: false),
          TaskModel(id: '8', name: 'Zararkunandalarni tekshirish', isCompleted: false),
        ],
      ),
    ];
    notifyListeners();
  }
  
  void toggleTask(String treeId, String taskId) {
    final treeIndex = _userTrees.indexWhere((t) => t.id == treeId);
    if (treeIndex != -1) {
      final taskIndex = _userTrees[treeIndex].tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        _userTrees[treeIndex].tasks[taskIndex].isCompleted = 
            !_userTrees[treeIndex].tasks[taskIndex].isCompleted;
        notifyListeners();
      }
    }
  }
  
  List<Map<String, dynamic>> get donationRanking => [
    {'rank': 1, 'name': 'Aziz Karimov', 'avatar': '🌳', 'amount': 5000000},
    {'rank': 2, 'name': 'Dilnoza Rahimova', 'avatar': '🌲', 'amount': 3500000},
    {'rank': 3, 'name': 'Rustam Saidov', 'avatar': '🌴', 'amount': 2800000},
    {'rank': 4, 'name': 'Nodira Yusupova', 'avatar': '🌿', 'amount': 2100000},
    {'rank': 5, 'name': 'Bobur Alimov', 'avatar': '🍃', 'amount': 1500000},
  ];
  
  List<Map<String, dynamic>> get activeRanking => [
    {'rank': 1, 'name': 'Sardor Toshev', 'avatar': '🌱', 'trees': 47},
    {'rank': 2, 'name': 'Malika Umarova', 'avatar': '🌼', 'trees': 38},
    {'rank': 3, 'name': 'Jasur Abdullayev', 'avatar': '🌻', 'trees': 31},
    {'rank': 4, 'name': 'Zarina Karimova', 'avatar': '🍀', 'trees': 25},
    {'rank': 5, 'name': 'Timur Nazarov', 'avatar': '🌾', 'trees': 22},
  ];
  
  UserModel get demoUser => UserModel(
    username: 'yashil_qahramon',
    fullName: 'Shahzod Mirzayev',
    phone: '+998 90 123 45 67',
    tasksCompletedToday: 5,
    totalPoints: 1250,
    promoCodes: ['BAHOR25', 'YASHIL2024'],
    badges: ['🌱 Yangi boshlovchi', '💧 Suv qahramoni', '🌳 Daraxt sevuvchi'],
    treesPlanted: 3,
  );
}
