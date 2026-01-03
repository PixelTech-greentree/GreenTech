import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/shop_models.dart';

class ShopApiService {
  final Dio _dio;
  final String? Function() getUserId;
  
  ShopApiService(this._dio, this.getUserId);

  // ==================== PRODUCTS ====================

  /// Barcha mahsulotlarni olish (Marketplace)
  Future<ApiResult<ProductListResponse>> getProducts({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? search,
    int page = 1,
    int perPage = 20,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      
      if (category != null) params['category'] = category;
      if (minPrice != null) params['min_price'] = minPrice;
      if (maxPrice != null) params['max_price'] = maxPrice;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (sortBy != null) params['sort_by'] = sortBy;
      if (sortOrder != null) params['sort_order'] = sortOrder;
      
      final response = await _dio.get('/api/v1/shop/products', queryParameters: params);
      return ApiResult.success(ProductListResponse.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Bitta mahsulot detallari
  Future<ApiResult<ProductModel>> getProduct(String productId) async {
    try {
      final response = await _dio.get('/api/v1/shop/products/$productId');
      return ApiResult.success(ProductModel.fromJson(response.data['product'] ?? response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Mening mahsulotlarim (Seller)
  Future<ApiResult<List<ProductModel>>> getMyProducts() async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final response = await _dio.get(
        '/api/v1/shop/my-products',
        queryParameters: {
          'seller_id': userId,
        },
      );
      
      final products = (response.data['products'] as List? ?? [])
          .map((p) => ProductModel.fromJson(p))
          .toList();
      return ApiResult.success(products);
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Yangi mahsulot yaratish (Seller)
  Future<ApiResult<ProductModel>> createProduct({
    required String name,
    String? description,
    required double price,
    required int stock,
    String? category,
    List<File>? images,
    Map<String, dynamic>? customFields,
  }) async {
    final userId = getUserId();
    if (userId == null) {
      return ApiResult.error('Foydalanuvchi topilmadi');
    }

    try {
      print('🔥 CREATE PRODUCT DEBUG START');
      print('Name: $name');
      print('Category: $category');
      print('Images count: ${images?.length ?? 0}');
      print('CustomFields: $customFields');
      
      // ======================
      // 1. Rasmlarni upload qilish
      // ======================
      final List<String> imageUrls = [];

      if (images != null && images.isNotEmpty) {
        print('📤 Uploading ${images.length} images...');
        for (int i = 0; i < images.length; i++) {
          final image = images[i];
          print('Uploading image ${i + 1}/${images.length}: ${image.path}');
          
          final uploadResult = await _uploadImage(image);

          if (!uploadResult.success || uploadResult.data == null) {
            print('❌ Upload failed: ${uploadResult.error}');
            return ApiResult.error(
              uploadResult.error ?? 'Rasm yuklashda xatolik',
            );
          }

          print('✅ Upload success: ${uploadResult.data}');
          imageUrls.add(uploadResult.data!);
        }
      }

      // ● Backend sharti
      if (imageUrls.isEmpty) {
        print('❌ No images uploaded');
        return ApiResult.error('Kamida bitta rasm yuklash majburiy');
      }

      print('✅ All images uploaded: $imageUrls');

      // ======================
      // 2. custom_fields ni tozalash (Map<String, String>)
      // ======================
      Map<String, String>? cleanedCustomFields;

      if (customFields != null && customFields.isNotEmpty) {
        print('🧹 Cleaning customFields...');
        cleanedCustomFields = {};
        
        customFields.forEach((key, value) {
          print('Processing field: $key = $value (${value.runtimeType})');
          
          // Agar value List bo'lsa
          if (value is List) {
            // List ichidagi har bir elementni String ga aylantiramiz
            final stringList = <String>[];
            for (var item in value) {
              stringList.add(item.toString());
            }
            final joined = stringList.join(',');
            cleanedCustomFields![key.toString()] = joined;
            print('  → List converted: $joined');
          } 
          // Agar value null bo'lmasa
          else if (value != null) {
            cleanedCustomFields![key.toString()] = value.toString();
            print('  → Converted to: ${value.toString()}');
          }
        });
        
        print('✅ Cleaned customFields: $cleanedCustomFields');
      }

      // ======================
      // 3. Request body (null maydonlarni yubormaymiz)
      // ======================
      final Map<String, dynamic> data = {
        'name': name,
        'price': price,
        'stock_quantity': stock,
        'image_urls': imageUrls,
      };

      if (description != null && description.isNotEmpty) {
        data['description'] = description;
      }

      if (category != null && category.isNotEmpty) {
        data['category'] = category;
      }

      if (cleanedCustomFields != null && cleanedCustomFields.isNotEmpty) {
        data['custom_fields'] = cleanedCustomFields;
      }

      print('📦 Final request data: $data');

      // ======================
      // 4. Product yaratish
      // ======================
      print('🚀 Sending POST request...');
      final response = await _dio.post(
        '/api/v1/shop/products',
        queryParameters: {'seller_id': userId},
        data: data,
      );

      print('✅ Product created successfully');
      print('🔥 CREATE PRODUCT DEBUG END');
      
      return ApiResult.success(
        ProductModel.fromJson(response.data['product'] ?? response.data),
      );
    } on DioException catch (e) {
      print('❌ DioException: ${e.message}');
      print('Response: ${e.response?.data}');
      return ApiResult.error(_handleError(e));
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('StackTrace: $stackTrace');
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Mahsulotni yangilash
Future<ApiResult<ProductModel>> updateProduct({
  required String productId,
  String? name,
  String? description,
  double? price,
  int? stock,
  String? category,
  List<String>? imageUrls,
  bool? isActive,
  Map<String, dynamic>? customFields,
}) async {
  final userId = getUserId();
  if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
  
  try {
    print('🔄 UPDATE PRODUCT DEBUG START');
    print('Product ID: $productId');
    print('Image URLs: $imageUrls');
    
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (price != null) data['price'] = price;
    if (stock != null) data['stock_quantity'] = stock;
    if (category != null) data['category'] = category;
    
    // ✅ MUHIM: imageUrls ni har doim yuborish (bo'sh ham bo'lsa)
    if (imageUrls != null) {
      data['image_urls'] = imageUrls;
      print('✅ Updating image_urls: $imageUrls');
    } else {
      print('⚠️ Warning: imageUrls is null!');
    }
    
    if (isActive != null) data['is_active'] = isActive;
    
    // customFields ni tozalash
    if (customFields != null && customFields.isNotEmpty) {
      final cleanedCustomFields = <String, String>{};
      customFields.forEach((key, value) {
        if (value is List) {
          cleanedCustomFields[key.toString()] = value.join(',');
        } else if (value != null) {
          cleanedCustomFields[key.toString()] = value.toString();
        }
      });
      if (cleanedCustomFields.isNotEmpty) {
        data['custom_fields'] = cleanedCustomFields;
      }
    }
    
    print('📦 Update data: $data');
    
    final response = await _dio.put(
      '/api/v1/shop/products/$productId',
      queryParameters: {'seller_id': userId},
      data: data,
    );
    
    print('✅ Product updated successfully');
    print('Response: ${response.data}');
    print('🔄 UPDATE PRODUCT DEBUG END');
    
    return ApiResult.success(ProductModel.fromJson(response.data['product'] ?? response.data));
  } on DioException catch (e) {
    print('❌ Update error: ${e.response?.data}');
    return ApiResult.error(_handleError(e));
  } catch (e, stackTrace) {
    print('❌ Unexpected error: $e');
    print('StackTrace: $stackTrace');
    return ApiResult.error('Xatolik: $e');
  }
}

  /// Mahsulotni o'chirish
  Future<ApiResult<bool>> deleteProduct(String productId) async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      await _dio.delete(
        '/api/v1/shop/products/$productId',
        queryParameters: {'seller_id': userId},
      );
      return ApiResult.success(true);
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  // ==================== CART ====================

  /// Savatni olish
  Future<ApiResult<CartModel>> getCart() async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final response = await _dio.get(
        '/api/v1/cart',
        queryParameters: {'user_id': userId},
      );
      return ApiResult.success(CartModel.fromJson(response.data['cart'] ?? response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Savatga qo'shish
  Future<ApiResult<CartModel>> addToCart(String productId, int quantity) async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final response = await _dio.post(
        '/api/v1/cart/add',
        queryParameters: {'user_id': userId},
        data: {
          'product_id': productId,
          'quantity': quantity,
        },
      );
      return ApiResult.success(CartModel.fromJson(response.data['cart'] ?? response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Savat itemini yangilash
  Future<ApiResult<CartModel>> updateCartItem(String itemId, int quantity) async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final response = await _dio.put(
        '/api/v1/cart/$itemId',
        queryParameters: {'user_id': userId},
        data: {'quantity': quantity},
      );
      return ApiResult.success(CartModel.fromJson(response.data['cart'] ?? response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Savat itemini o'chirish
  Future<ApiResult<CartModel>> removeFromCart(String itemId) async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final response = await _dio.delete(
        '/api/v1/cart/$itemId',
        queryParameters: {'user_id': userId},
      );
      return ApiResult.success(CartModel.fromJson(response.data['cart'] ?? response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Savatni tozalash
  Future<ApiResult<bool>> clearCart() async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      await _dio.delete(
        '/api/v1/cart/clear',
        queryParameters: {'user_id': userId},
      );
      return ApiResult.success(true);
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  // ==================== ORDERS ====================

  /// Buyurtma yaratish
  Future<ApiResult<OrderModel>> createOrder({String? note}) async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final data = <String, dynamic>{};
      if (note != null) data['note'] = note;
      
      final response = await _dio.post(
        '/api/v1/orders/create',
        queryParameters: {'user_id': userId},
        data: data.isNotEmpty ? data : null,
      );
      return ApiResult.success(OrderModel.fromJson(response.data['order'] ?? response.data));
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Mening buyurtmalarim (Buyer)
  Future<ApiResult<List<OrderModel>>> getMyOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final params = <String, dynamic>{
        'user_id': userId,
        'page': page,
        'per_page': perPage,
      };
      if (status != null) params['status'] = status;
      
      final response = await _dio.get('/api/v1/orders/my/list', queryParameters: params);
      
      final orders = (response.data['orders'] as List? ?? [])
          .map((o) => OrderModel.fromJson(o))
          .toList();
      return ApiResult.success(orders);
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Sotuvchi buyurtmalari (Seller)
  Future<ApiResult<List<OrderModel>>> getSellerOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final params = <String, dynamic>{
        'seller_id': userId,
        'page': page,
        'per_page': perPage,
      };
      if (status != null) params['status'] = status;
      
      final response = await _dio.get('/api/v1/orders/seller/list', queryParameters: params);
      
      final orders = (response.data['orders'] as List? ?? [])
          .map((o) => OrderModel.fromJson(o))
          .toList();
      return ApiResult.success(orders);
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

// ✅ YANGI - Item statusini yangilash
  Future<ApiResult<bool>> updateOrderItemStatus(
    String itemId,
    String sellerId,
    String status,
  ) async {
    try {
      print('📤 [API] Updating item status...');
      print('Item ID: $itemId');
      print('Seller ID: $sellerId');
      print('New Status: $status');

      final response = await _dio.put(
        '/api/v1/orders/items/$itemId/status',
        queryParameters: {'seller_id': sellerId},
        data: {'status': status},
      );

      print('✅ [API] Response: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult.success(true);
      }
      
      return ApiResult.error('Failed to update item status');
    } catch (e) {
      print('❌ [API] Error: $e');
      return ApiResult.error(e.toString());
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Sotuvchi uchun notificationlar
  Future<ApiResult<List<OrderNotificationModel>>> getOrderNotifications() async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final response = await _dio.get(
        '/api/v1/notifications/orders',
        queryParameters: {'seller_id': userId},
      );
      
      final notifications = (response.data['notifications'] as List? ?? [])
          .map((n) => OrderNotificationModel.fromJson(n))
          .toList();
      return ApiResult.success(notifications);
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// Notificationni o'qilgan deb belgilash
  Future<ApiResult<bool>> markNotificationRead(String notificationId) async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      await _dio.put(
        '/api/v1/notifications/$notificationId/read',
        queryParameters: {'seller_id': userId},
      );
      return ApiResult.success(true);
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  /// O'qilmagan notificationlar soni
  Future<ApiResult<int>> getUnreadNotificationCount() async {
    final userId = getUserId();
    if (userId == null) return ApiResult.error('Foydalanuvchi topilmadi');
    
    try {
      final response = await _dio.get(
        '/api/v1/notifications/orders/unread-count',
        queryParameters: {'seller_id': userId},
      );
      return ApiResult.success(response.data['unread_count'] ?? 0);
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Xatolik: $e');
    }
  }

  // ==================== IMAGE UPLOAD ====================

  /// Rasm yuklash (to'g'rilangan)
  Future<ApiResult<String>> _uploadImage(File imageFile) async {
    try {
      // Fayl kengaytmasini aniqlash
      final String fileName = imageFile.path.split('/').last;
      final String extension = fileName.split('.').last.toLowerCase();
      
      // MIME type ni to'g'ri aniqlash
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      // MultipartFile yaratish
      final multipartFile = await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      );

      // FormData yaratish - field nomi 'file' bo'lishi kerak
      final formData = FormData();
      formData.files.add(MapEntry('file', multipartFile));

      // Upload qilish
      final response = await _dio.post(
        '/api/v1/upload/image',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (status) => status! < 500,
        ),
      );

      // Response tekshirish
      if (response.statusCode == 422) {
        return ApiResult.error('Server xatosi: ${response.data}');
      }

      if (response.data is Map && 
          response.data['success'] == true && 
          response.data['url'] != null) {
        return ApiResult.success(response.data['url'] as String);
      } else {
        return ApiResult.error('Rasm URL olinmadi: ${response.data}');
      }
    } on DioException catch (e) {
      return ApiResult.error(_handleError(e));
    } catch (e) {
      return ApiResult.error('Rasm yuklashda xatolik: $e');
    }
  }

  /// Rasmlarni yuklash (public method)
  Future<ApiResult<List<String>>> uploadImages(List<File> images) async {
    try {
      List<String> urls = [];
      for (final image in images) {
        final result = await _uploadImage(image);
        if (result.success && result.data != null) {
          urls.add(result.data!);
        } else {
          return ApiResult.error(result.error ?? 'Rasm yuklashda xatolik');
        }
      }
      return ApiResult.success(urls);
    } catch (e) {
      return ApiResult.error('Rasmlarni yuklashda xatolik: $e');
    }
  }

  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Internet ulanish vaqti tugadi';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Internet bilan bog\'liq xatolik';
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