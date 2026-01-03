// ==================== SHOP MODELS ====================

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

// ==================== PRODUCT ====================

class ProductModel {
  final String id;
  final String sellerId;
  final String name;
  final String? description;
  final double price;
  final String? category;
  final List<String> imageUrls;
  final String? primaryImage;
  final int stock_quantity;
  final bool isActive;
  final Map<String, dynamic>? customFields;
  final String? createdAt;
  final String? updatedAt;
  
  // Seller info (from API response)
  final String? sellerName;
  final String? sellerPhone;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    this.description,
    required this.price,
    this.category,
    required this.imageUrls,
    this.primaryImage,
    required this.stock_quantity,
    this.isActive = true,
    this.customFields,
    this.createdAt,
    this.updatedAt,
    this.sellerName,
    this.sellerPhone,
  });

factory ProductModel.fromJson(Map<String, dynamic> json) {
  List<String> images = [];
  
  // 1. API'dan images array (yangi format)
  if (json['images'] != null && json['images'] is List) {
    images = (json['images'] as List)
        .map((img) => img['image_url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
  }
  // 2. image_urls array (eski format)
  else if (json['image_urls'] != null && json['image_urls'] is List) {
    images = (json['image_urls'] as List)
        .map((e) => e.toString())
        .where((url) => url.isNotEmpty)
        .toList();
  }
  
  return ProductModel(
    id: json['product_id']?.toString() ?? json['id']?.toString() ?? '',
    sellerId: json['seller_id']?.toString() ?? '',
    name: json['name'] ?? '',
    description: json['description'],
    price: _parseDouble(json['price']),
    category: json['category'],
    imageUrls: images, // ✅ Hamma rasmlar shu yerda
    primaryImage: json['primary_image'],
    stock_quantity: _parseInt(json['stock_quantity']),
    isActive: json['is_active'] ?? true,
    customFields: json['custom_fields'],
    createdAt: json['created_at'],
    updatedAt: json['updated_at'],
    sellerName: json['seller_name'] ?? json['seller']?['full_name'],
    sellerPhone: json['seller_phone'] ?? json['seller']?['phone_number'],
  );
}
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'category': category,
    'image_urls': imageUrls,
    'stock_quantity': stock_quantity,
    'is_active': isActive,
    'custom_fields': customFields,
  };
  
  String get displayImage => primaryImage ?? (imageUrls.isNotEmpty ? imageUrls.first : '');
  bool get inStock => stock_quantity > 0;
}

// ==================== CART ITEM ====================

class CartItemModel {
  final String id;
  final String cartId;
  final String productId;
  final int quantity;
  final double priceAtAdd;
  final double subtotal;
  final String? addedAt;
  
  // Product details
  final ProductModel? product;

  CartItemModel({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.quantity,
    required this.priceAtAdd,
    required this.subtotal,
    this.addedAt,
    this.product,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    ProductModel? product;
    if (json['product'] != null) {
      product = ProductModel.fromJson(json['product']);
    }
    
    return CartItemModel(
      id: json['item_id']?.toString() ?? json['id']?.toString() ?? '',
      cartId: json['cart_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      quantity: _parseInt(json['quantity']),
      priceAtAdd: _parseDouble(json['price_at_add']),
      subtotal: _parseDouble(json['subtotal']),
      addedAt: json['added_at'],
      product: product,
    );
  }
}

// ==================== CART ====================

class CartModel {
  final String id;
  final String userId;
  final List<CartItemModel> items;
  final double totalAmount;
  final int itemCount;
  final String? createdAt;
  final String? updatedAt;

  CartModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.itemCount,
    this.createdAt,
    this.updatedAt,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    List<CartItemModel> items = [];
    if (json['items'] != null) {
      items = (json['items'] as List)
          .map((item) => CartItemModel.fromJson(item))
          .toList();
    }
    
    return CartModel(
      id: json['cart_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      items: items,
      totalAmount: _parseDouble(json['total_amount'] ?? json['total']),
      itemCount: _parseInt(json['item_count']),
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

// ==================== ORDER ITEM ====================

class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final String sellerId;
  final int quantity;
  final double priceAtPurchase;
  final double subtotal;
  
  // ✅ YANGI fieldlar
  final String productName;
  final double productPrice;
  final String sellerName;
  final String status;  // ← ASOSIY YANGILIK
  
  // Eski fieldlar (optional)
  final String? productImage;
  final ProductModel? product;
  final String? createdAt;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.sellerId,
    required this.quantity,
    required this.priceAtPurchase,
    required this.subtotal,
    required this.productName,
    required this.productPrice,
    required this.sellerName,
    required this.status,
    this.productImage,
    this.product,
    this.createdAt,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    ProductModel? product;
    if (json['product'] != null) {
      product = ProductModel.fromJson(json['product']);
    }
    
    return OrderItemModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      quantity: _parseInt(json['quantity']),
      priceAtPurchase: _parseDouble(json['product_price'] ?? json['price_at_purchase']),
      subtotal: _parseDouble(json['subtotal']),
      
      // ✅ YANGI
      productName: json['product_name'] ?? product?.name ?? '',
      productPrice: _parseDouble(json['product_price']),
      sellerName: json['seller_name'] ?? '',
      status: json['status'] ?? 'pending',
      
      productImage: json['product_image'] ?? product?.displayImage,
      product: product,
      createdAt: json['created_at'],
    );
  }
  
  // ✅ STATUS TEXT GETTER
  String get statusText {
    switch (status) {
      case 'pending': return 'Kutilmoqda';
      case 'confirmed': return 'Tasdiqlangan';
      case 'shipped': return 'Jo\'natilgan';
      case 'completed': return 'Yakunlangan';
      case 'cancelled': return 'Bekor qilingan';
      case 'rejected': return 'Qaytarilgan';
      default: return status;
    }
  }
  
  // Eski getterlar (boshqa joyda ishlatilsa)
  ProductModel get item {
    return product ?? ProductModel(
      id: productId,
      sellerId: sellerId,
      name: productName,
      price: productPrice,
      imageUrls: productImage != null ? [productImage!] : [],
      stock_quantity: 0,
    );
  }
  
  double get totalPrice => subtotal;
}

// ==================== ORDER ====================

class OrderModel {
  final String id;
  final String buyerId;
  final double totalAmount;
  final String? note;
  final String? createdAt;
  final String? updatedAt;
  final List<OrderItemModel> items;
  
  // ✅ YANGI fieldlar
  final String buyerName;
  final String buyerPhone;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.totalAmount,
    this.note,
    this.createdAt,
    this.updatedAt,
    required this.items,
    required this.buyerName,
    required this.buyerPhone,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItemModel> items = [];
    if (json['items'] != null) {
      items = (json['items'] as List)
          .map((item) => OrderItemModel.fromJson(item))
          .toList();
    }
    
    return OrderModel(
      id: json['id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      totalAmount: _parseDouble(json['total_amount']),
      note: json['note'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      items: items,
      
      // ✅ YANGI
      buyerName: json['buyer_name'] ?? '',
      buyerPhone: json['buyer_phone'] ?? '',
    );
  }
  
  // ✅ Eski getterlar (profile_screen uchun)
  DateTime get date {
    if (createdAt == null || createdAt!.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(createdAt!);
    } catch (e) {
      return DateTime.now();
    }
  }
  
  double get total => totalAmount;
}
// ==================== ORDER NOTIFICATION ====================

class OrderNotificationModel {
  final String id;
  final String orderId;
  final String sellerId;
  final String buyerId;
  final String? buyerName;
  final String? buyerPhone;
  final double orderTotal;
  final int itemCount;
  final String? note;
  final bool isRead;
  final String? readAt;
  final String createdAt;

  OrderNotificationModel({
    required this.id,
    required this.orderId,
    required this.sellerId,
    required this.buyerId,
    this.buyerName,
    this.buyerPhone,
    required this.orderTotal,
    required this.itemCount,
    this.note,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory OrderNotificationModel.fromJson(Map<String, dynamic> json) {
    return OrderNotificationModel(
      id: json['notification_id']?.toString() ?? json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      buyerName: json['buyer_name'],
      buyerPhone: json['buyer_phone'],
      orderTotal: _parseDouble(json['order_total']),
      itemCount: _parseInt(json['item_count']),
      note: json['note'],
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

// ==================== API RESPONSES ====================

class ProductListResponse {
  final List<ProductModel> products;
  final int total;
  final int page;
  final int perPage;

  ProductListResponse({
    required this.products,
    required this.total,
    required this.page,
    required this.perPage,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    List<ProductModel> products = [];
    if (json['products'] != null) {
      products = (json['products'] as List)
          .map((p) => ProductModel.fromJson(p))
          .toList();
    }
    
    return ProductListResponse(
      products: products,
      total: _parseInt(json['total']),
      page: _parseInt(json['page']),
      perPage: _parseInt(json['per_page']),
    );
  }
}
