import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/shop_models.dart';
import 'shop_api_service.dart';

class ShopState extends ChangeNotifier {
  ShopApiService? _api;
  
  // Default constructor - api keyin set qilinadi
  ShopState([ShopApiService? api]) : _api = api;
  
  // API ni set qilish
  void setApi(ShopApiService api) {
    _api = api;
    notifyListeners();
  }
  
  // ========== Products ==========
  List<ProductModel> _allProducts = [];
  List<ProductModel> _myProducts = [];
  bool _isLoadingProducts = false;
  bool _isLoadingMyProducts = false;
  String? _productError;
  bool _hasMoreProducts = true;
  int _currentPage = 1;
  String? _currentCategory;
  String? _currentSearch;
  
  List<ProductModel> get allProducts => _allProducts;
  List<ProductModel> get myProducts => _myProducts;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingMyProducts => _isLoadingMyProducts;
  String? get productError => _productError;
  bool get hasMoreProducts => _hasMoreProducts;
  
  // ========== Cart ==========
  CartModel? _cart;
  bool _isLoadingCart = false;
  
  CartModel? get cart => _cart;
  bool get isLoadingCart => _isLoadingCart;
  List<CartItemModel> get cartItems => _cart?.items ?? [];
  int get cartItemCount => cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
  
  // ========== Orders ==========
  List<OrderModel> _myOrders = [];
  List<OrderModel> _sellerOrders = [];
  bool _isLoadingOrders = false;
  
  List<OrderModel> get myOrders => _myOrders;
  List<OrderModel> get sellerOrders => _sellerOrders;
  bool get isLoadingOrders => _isLoadingOrders;
  
  // Eski kod uchun moslik - orders getter
  List<OrderModel> get orders => _myOrders;
  
  // ========== Notifications ==========
  List<OrderNotificationModel> _notifications = [];
  bool _isLoadingNotifications = false;
  int _unreadNotificationCount = 0;
  
  List<OrderNotificationModel> get notifications => _notifications;
  bool get isLoadingNotifications => _isLoadingNotifications;
  int get unreadNotificationCount => _unreadNotificationCount;
  
  // ========== PRODUCT METHODS ==========
  
  Future<void> loadProducts({
    String? category,
    String? search,
    bool refresh = false,
  }) async {
    if (_api == null) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMoreProducts = true;
      _allProducts = [];
    }
    
    if (!_hasMoreProducts || _isLoadingProducts) return;
    
    _isLoadingProducts = true;
    _productError = null;
    _currentCategory = category;
    _currentSearch = search;
    notifyListeners();
    
    final result = await _api!.getProducts(
      page: _currentPage,
      perPage: 20,
      category: category,
      search: search,
    );
    
    if (result.success && result.data != null) {
      if (refresh) {
        _allProducts = result.data!.products;
      } else {
        _allProducts.addAll(result.data!.products);
      }
      _hasMoreProducts = result.data!.products.length >= 20;
      _currentPage++;
    } else {
      _productError = result.error;
    }
    
    _isLoadingProducts = false;
    notifyListeners();
  }
  
  Future<void> loadMoreProducts() async {
    if (_hasMoreProducts && !_isLoadingProducts) {
      await loadProducts(
        category: _currentCategory,
        search: _currentSearch,
      );
    }
  }
  
  Future<void> loadMyProducts() async {
    if (_api == null) return;
    
    _isLoadingMyProducts = true;
    notifyListeners();
    
    final result = await _api!.getMyProducts();
    
    if (result.success && result.data != null) {
      _myProducts = result.data!;
    }
    
    _isLoadingMyProducts = false;
    notifyListeners();
  }
  
  Future<ApiResult<ProductModel>> createProduct({
    required String name,
    String? description,
    required double price,
    required int stock,
    String? category,
    List<File>? images,
    Map<String, dynamic>? customFields,
  }) async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    final result = await _api!.createProduct(
      name: name,
      description: description,
      price: price,
      stock: stock,
      category: category,
      images: images ?? [],
      customFields: customFields,
    );
    
    if (result.success) {
      await loadMyProducts();
    }
    
    return result;
  }

  Future<ApiResult<ProductModel>> updateProduct({
  required String productId,
  String? name,
  String? description,
  double? price,
  int? stock,
  String? category,
  List<String>? imageUrls,
  Map<String, dynamic>? customFields,
}) async {
  if (_api == null) {
    return ApiResult.error('API not initialized');
  }

  print('🔄 [ShopState] updateProduct called');
  print('Product ID: $productId');
  print('Image URLs received: $imageUrls');

  final result = await _api!.updateProduct(
    productId: productId,
    name: name,
    description: description,
    price: price,
    stock: stock,
    category: category,
    imageUrls: imageUrls, // ✅ To'g'ridan-to'g'ri yuboriladi
    customFields: customFields,
  );

  if (result.success) {
    print('✅ [ShopState] Update successful, reloading products...');
    await loadMyProducts();
  } else {
    print('❌ [ShopState] Update failed: ${result.error}');
  }

  return result;
}


  
  Future<ApiResult<bool>> deleteProduct(String productId) async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    final result = await _api!.deleteProduct(productId);
    
    if (result.success) {
      _myProducts.removeWhere((p) => p.id == productId);
      notifyListeners();
    }
    
    return result;
  }
  
  Future<ApiResult<List<String>>> uploadImages(List<File> images) async {
    if (_api == null) return ApiResult.error('API not initialized');
    return await _api!.uploadImages(images);
  }
  
  // ========== CART METHODS ==========
  
  Future<void> loadCart() async {
    if (_api == null) return;
    
    _isLoadingCart = true;
    notifyListeners();
    
    final result = await _api!.getCart();
    
    if (result.success && result.data != null) {
      _cart = result.data;
    }
    
    _isLoadingCart = false;
    notifyListeners();
  }
  
  Future<ApiResult<CartModel>> addToCart(String productId, {int quantity = 1}) async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    final result = await _api!.addToCart(productId, quantity);
    
    if (result.success) {
      await loadCart();
    }
    
    return result;
  }
  
  Future<ApiResult<CartModel>> updateCartItem(String itemId, int quantity) async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    final result = await _api!.updateCartItem(itemId, quantity);
    
    if (result.success) {
      await loadCart();
    }
    
    return result;
  }
  
  Future<ApiResult<CartModel>> removeFromCart(String itemId) async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    final result = await _api!.removeFromCart(itemId);
    
    if (result.success) {
      await loadCart();
    }
    
    return result;
  }
  
  Future<ApiResult<bool>> clearCart() async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    final result = await _api!.clearCart();
    
    if (result.success) {
      _cart = null;
      notifyListeners();
    }
    
    return result;
  }
  
  // ========== ORDER METHODS ==========
  
  Future<ApiResult<OrderModel>> createOrder({String? note}) async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    final result = await _api!.createOrder(note: note);
    
    if (result.success) {
      _cart = null;
      await loadMyOrders();
      notifyListeners();
    }
    
    return result;
  }
  
  Future<void> loadMyOrders() async {
    if (_api == null) return;
    
    _isLoadingOrders = true;
    notifyListeners();
    
    final result = await _api!.getMyOrders();
    
    if (result.success && result.data != null) {
      _myOrders = result.data!;
    }
    
    _isLoadingOrders = false;
    notifyListeners();
  }
  
  Future<void> loadSellerOrders() async {
    if (_api == null) return;
    
    _isLoadingOrders = true;
    notifyListeners();
    
    final result = await _api!.getSellerOrders();
    
    if (result.success && result.data != null) {
      _sellerOrders = result.data!;
    }
    
    _isLoadingOrders = false;
    notifyListeners();
  }
  
  // Eski kod uchun moslik
  Future<void> loadOrders() async {
    await loadMyOrders();
  }
  
// ✅ YANGI - Item statusini yangilash
  Future<ApiResult<bool>> updateOrderItemStatus(
    String itemId,
    String sellerId,
    String status,
  ) async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    print('🔄 [ShopState] Updating item status...');
    
    final result = await _api!.updateOrderItemStatus(itemId, sellerId, status);
    
    if (result.success) {
      print('✅ [ShopState] Update successful, reloading orders...');
      // Seller orderlarni qayta yuklash
      await loadSellerOrders();
    } else {
      print('❌ [ShopState] Update failed: ${result.error}');
    }
    
    return result;
  }
  
  // ========== NOTIFICATION METHODS ==========
  
  Future<void> loadNotifications() async {
    if (_api == null) return;
    
    _isLoadingNotifications = true;
    notifyListeners();
    
    final result = await _api!.getOrderNotifications();
    
    if (result.success && result.data != null) {
      _notifications = result.data!;
      _unreadNotificationCount = _notifications.where((n) => !n.isRead).length;
    }
    
    _isLoadingNotifications = false;
    notifyListeners();
  }
  
  Future<ApiResult<bool>> markNotificationRead(String notificationId) async {
    if (_api == null) return ApiResult.error('API not initialized');
    
    final result = await _api!.markNotificationRead(notificationId);
    
    if (result.success) {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        // O'qilgan deb belgilash
        _notifications[index] = OrderNotificationModel(
          id: _notifications[index].id,
          orderId: _notifications[index].orderId,
          sellerId: _notifications[index].sellerId,
          buyerId: _notifications[index].buyerId,
          buyerName: _notifications[index].buyerName,
          buyerPhone: _notifications[index].buyerPhone,
          orderTotal: _notifications[index].orderTotal,
          itemCount: _notifications[index].itemCount,
          isRead: true,
          createdAt: _notifications[index].createdAt,
          note: _notifications[index].note,
        );
        _unreadNotificationCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    }
    
    return result;
  }
  
  Future<void> loadUnreadNotificationCount() async {
    if (_api == null) return;
    
    final result = await _api!.getUnreadNotificationCount();
    
    if (result.success && result.data != null) {
      _unreadNotificationCount = result.data!;
      notifyListeners();
    }
  }
  
  // ========== CLEAR ==========
  
  void clear() {
    _allProducts = [];
    _myProducts = [];
    _cart = null;
    _myOrders = [];
    _sellerOrders = [];
    _notifications = [];
    _unreadNotificationCount = 0;
    _currentPage = 1;
    _hasMoreProducts = true;
    notifyListeners();
  }
}