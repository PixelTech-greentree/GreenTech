import 'package:flutter/material.dart';

class ShopItem {
  final String id;
  final String name;
  final String nameUz;
  final double price;
  final String imageUrl;
  final String category;
  final String description;
  final bool inStock;

  ShopItem({
    required this.id,
    required this.name,
    required this.nameUz,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.description,
    this.inStock = true,
  });
}

class CartItem {
  final ShopItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});

  double get totalPrice => item.price * quantity;
}

class Order {
  final String id;
  final List<CartItem> items;
  final double total;
  final DateTime date;
  final String status;

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.date,
    required this.status,
  });
}

class ShopState extends ChangeNotifier {
  final List<ShopItem> _allItems = [
    // Fertilizers
    ShopItem(
      id: '1',
      name: 'Organic Fertilizer',
      nameUz: 'Organik o\'g\'it',
      price: 45000,
      imageUrl: 'https://images.unsplash.com/photo-1589923158776-cb4485d99fd6?w=400',
      category: 'fertilizer',
      description: 'Tabiiy organik o\'g\'it, barcha o\'simliklar uchun',
    ),
    ShopItem(
      id: '2',
      name: 'NPK Complex',
      nameUz: 'NPK Kompleks',
      price: 35000,
      imageUrl: 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=400',
      category: 'fertilizer',
      description: 'Azot, fosfor va kaliy bilan boyitilgan',
    ),
    ShopItem(
      id: '3',
      name: 'Liquid Fertilizer',
      nameUz: 'Suyuq o\'g\'it',
      price: 28000,
      imageUrl: 'https://images.unsplash.com/photo-1615671524827-c1fe3973b648?w=400',
      category: 'fertilizer',
      description: 'Tez ta\'sir qiluvchi suyuq o\'g\'it',
    ),
    
    // Tools
    ShopItem(
      id: '4',
      name: 'Garden Trowel',
      nameUz: 'Bog\' ketmonchasi',
      price: 25000,
      imageUrl: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
      category: 'tool',
      description: 'Zanglamaydigan po\'latdan yasalgan',
    ),
    ShopItem(
      id: '5',
      name: 'Pruning Shears',
      nameUz: 'Bog\' qaychi',
      price: 55000,
      imageUrl: 'https://images.unsplash.com/photo-1617041387726-c3747a912d14?w=400',
      category: 'tool',
      description: 'Professional budama qaychi',
    ),
    ShopItem(
      id: '6',
      name: 'Watering Can',
      nameUz: 'Sug\'orish idishi',
      price: 18000,
      imageUrl: 'https://images.unsplash.com/photo-1563656157432-67560011e209?w=400',
      category: 'tool',
      description: '5 litrlik plastik sug\'orish idishi',
    ),
    ShopItem(
      id: '7',
      name: 'Hand Rake',
      nameUz: 'Qo\'l tirmi',
      price: 15000,
      imageUrl: 'https://images.unsplash.com/photo-1617041387726-c3747a912d14?w=400',
      category: 'tool',
      description: 'Tuproqni yumshatish uchun',
    ),
    
    // Pots & Containers
    ShopItem(
      id: '8',
      name: 'Ceramic Pot',
      nameUz: 'Sopol gorshok',
      price: 40000,
      imageUrl: 'https://images.unsplash.com/photo-1485955900006-10f4d324d411?w=400',
      category: 'pot',
      description: 'Zamonaviy dizayndagi sopol gorshok',
    ),
    ShopItem(
      id: '9',
      name: 'Plastic Planter',
      nameUz: 'Plastik konteyner',
      price: 12000,
      imageUrl: 'https://images.unsplash.com/photo-1591958911259-bee2173bdccc?w=400',
      category: 'pot',
      description: 'Turli o\'lchamdagi plastik gorshok',
    ),
    
    // Seeds & Soil
    ShopItem(
      id: '10',
      name: 'Potting Soil',
      nameUz: 'O\'simlik tuprog\'i',
      price: 20000,
      imageUrl: 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=400',
      category: 'soil',
      description: '10kg tayyor aralashma tuproq',
    ),
    ShopItem(
      id: '11',
      name: 'Herb Seeds Mix',
      nameUz: 'Ziravorlar urug\'i',
      price: 8000,
      imageUrl: 'https://images.unsplash.com/photo-1464454709131-ffd692591ee5?w=400',
      category: 'seed',
      description: 'Rayhon, ukrop, petrushka urug\'lari',
    ),
    ShopItem(
      id: '12',
      name: 'Plant Growth Light',
      nameUz: 'O\'simlik chirog\'i',
      price: 85000,
      imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
      category: 'accessory',
      description: 'LED o\'sish chirog\'i',
    ),
  ];

  List<CartItem> _cartItems = [];
  List<Order> _orders = [];

  List<ShopItem> get allItems => _allItems;
  List<CartItem> get cartItems => _cartItems;
  List<Order> get orders => _orders;
  
  int get cartItemCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => _cartItems.fold(0, (sum, item) => sum + item.totalPrice);

  void addToCart(ShopItem item) {
    final existingIndex = _cartItems.indexWhere((ci) => ci.item.id == item.id);
    if (existingIndex >= 0) {
      _cartItems[existingIndex].quantity++;
    } else {
      _cartItems.add(CartItem(item: item));
    }
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    _cartItems.removeWhere((ci) => ci.item.id == itemId);
    notifyListeners();
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _cartItems.indexWhere((ci) => ci.item.id == itemId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  void checkout() {
    if (_cartItems.isEmpty) return;
    
    final order = Order(
      id: 'ORD${DateTime.now().millisecondsSinceEpoch}',
      items: List.from(_cartItems),
      total: cartTotal,
      date: DateTime.now(),
      status: 'pending',
    );
    
    _orders.insert(0, order);
    _cartItems.clear();
    notifyListeners();
  }

  List<ShopItem> getItemsByCategory(String category) {
    return _allItems.where((item) => item.category == category).toList();
  }
}