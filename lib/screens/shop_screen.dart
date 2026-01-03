import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../services/shop_state.dart';
import '../models/shop_models.dart';
import 'product_detail_screen.dart';
import 'add_product_screen.dart';
import 'cart_screen.dart';
import 'order_notifications_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver,RouteAware {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';

  final Map<String, String> _categories = {
    'all': 'Hammasi',
    'fertilizer': 'O\'g\'itlar',
    'tool': 'Asboblar',
    'pot': 'Gorshoklar',
    'seed': 'Urug\'lar',
    'soil': 'Tuproq',
    'accessory': 'Aksessuarlar',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }
  @override
  void didPopNext() {
    _loadData(); // ✅ Refresh
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this); 
    super.dispose();
  }

  Future<void> _loadData() async {
    final shopState = context.read<ShopState>();
    await Future.wait([
      shopState.loadProducts(refresh: true),
      shopState.loadMyProducts(),
      shopState.loadCart(),
      shopState.loadUnreadNotificationCount(),  // ✅ refreshUnreadCount o'rniga
    ]);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  // _onCategoryChanged metodini tuzatish (65-qator atrofida):
  void _onCategoryChanged(String category) {
    setState(() => _selectedCategory = category);
    // ✅ setCategory o'rniga to'g'ridan-to'g'ri loadProducts
    context.read<ShopState>().loadProducts(
      category: category == 'all' ? null : category,
      refresh: true,
    );
  }

  // _onSearch metodini tuzatish (70-qator atrofida):
  void _onSearch(String query) {
    // ✅ setSearchQuery o'rniga to'g'ridan-to'g'ri loadProducts
    context.read<ShopState>().loadProducts(
      search: query.isEmpty ? null : query,
      refresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopState>(
      builder: (context, shopState, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(shopState),
                
                // Tab bar
                _buildTabBar(),
                
                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMarketplaceTab(shopState),
                      _buildMyProductsTab(shopState),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ShopState shopState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen.withOpacity(0.1),
            AppColors.softGreen,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🌿 Do\'kon',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Bog\' uchun mahsulotlar',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // Notification button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderNotificationsScreen()),
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(Icons.notifications_outlined, color: AppColors.primaryGreen, size: 24),
                      ),
                      if (shopState.unreadNotificationCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '${shopState.unreadNotificationCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Cart button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) =>  CartScreen()),
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(Icons.shopping_cart_outlined, color: AppColors.primaryGreen, size: 24),
                      ),
                      if (shopState.cartItemCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '${shopState.cartItemCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMedium,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront, size: 18),
                SizedBox(width: 6),
                Text('Mahsulotlar'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 18),
                SizedBox(width: 6),
                Text('Mening'),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildMarketplaceTab(ShopState shopState) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Mahsulot qidirish...',
                hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textLight),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 150.ms),
        
        const SizedBox(height: 12),
        
        // Categories
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final key = _categories.keys.elementAt(index);
              final label = _categories[key]!;
              final isSelected = _selectedCategory == key;
              
              return GestureDetector(
                onTap: () => _onCategoryChanged(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryGreen.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : AppColors.cardShadow,
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppColors.textLight.withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textMedium,
                    ),
                  ),
                ),
              );
            },
          ),
        ).animate().fadeIn(delay: 200.ms),
        
        const SizedBox(height: 16),
        
        // Products grid
        Expanded(
          child: shopState.isLoadingProducts && shopState.allProducts.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : shopState.allProducts.isEmpty
                  ? _buildEmptyState('Mahsulotlar topilmadi', '🛒')
                  : RefreshIndicator(
                      onRefresh: () => shopState.loadProducts(refresh: true),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: shopState.allProducts.length,
                        itemBuilder: (context, index) {
                          final product = shopState.allProducts[index];
                          return _ProductCard(
                            product: product,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(productId: product.id),
                              ),
                            ),
                            onAddToCart: () async {
                              final result = await shopState.addToCart(product.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.success
                                          ? '${product.name} savatga qo\'shildi'
                                          : result.error ?? 'Xatolik',
                                    ),
                                    backgroundColor: result.success ? AppColors.success : AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          ).animate().scale(delay: Duration(milliseconds: 50 * (index % 6)));
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMyProductsTab(ShopState shopState) {
    return Column(
      children: [
        // Add product button
        Padding(
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddProductScreen()),
            ).then((_) => shopState.loadMyProducts()),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen.withOpacity(0.15),
                    AppColors.accentBlue.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yangi mahsulot qo\'shish',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mahsulotingizni sotuvga qo\'ying',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: AppColors.primaryGreen, size: 18),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),
        
        // My products list
        Expanded(
          child: shopState.isLoadingMyProducts
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : shopState.myProducts.isEmpty
                  ? _buildEmptyState('Hali mahsulot qo\'shmadingiz', '📦')
                  : RefreshIndicator(
                      onRefresh: () => shopState.loadMyProducts(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: shopState.myProducts.length,
                        itemBuilder: (context, index) {
                          final product = shopState.myProducts[index];
                          return _MyProductCard(
                            product: product,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                  productId: product.id,
                                  isOwner: true,
                                ),
                              ),
                            ),
                            onEdit: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddProductScreen(product: product),
                              ),
                            ).then((_) => shopState.loadMyProducts()),
                            onDelete: () => _showDeleteDialog(product, shopState),
                          ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.05, end: 0);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, String emoji) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showDeleteDialog(ProductModel product, ShopState shopState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mahsulotni o\'chirish'),
        content: Text('${product.name} ni o\'chirishni xohlaysizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await shopState.deleteProduct(product.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.success ? 'O\'chirildi' : result.error ?? 'Xatolik'),
                    backgroundColor: result.success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }
}

// Product Card for Marketplace
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'uz_UZ');
    return '${formatter.format(price)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.softGreen.withOpacity(0.5),
                            AppColors.mintGreen.withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: product.displayImage.isNotEmpty
                          ? Image.network(
                              product.displayImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image, size: 48, color: AppColors.textLight),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.spa, size: 48, color: AppColors.primaryGreen),
                            ),
                    ),
                  ),
                  // Stock badge
                  if (!product.inStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Tugagan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info - ✅ YECHIM
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10), // ✅ 12 → 10
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // ✅ QO'SHILDI
                  children: [
                    // ✅ Flexible qo'shildi
                    Flexible(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 13, // ✅ 14 → 13
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4), // ✅ Spacer o'rniga fix height
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end, // ✅ QO'SHILDI
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, // ✅ QO'SHILDI
                            children: [
                              Text(
                                _formatPrice(product.price),
                                style: const TextStyle(
                                  fontSize: 14, // ✅ 15 → 14
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryGreen,
                                ),
                                overflow: TextOverflow.ellipsis, // ✅ QO'SHILDI
                                maxLines: 1, // ✅ QO'SHILDI
                              ),
                              const Text(
                                'so\'m',
                                style: TextStyle(
                                  fontSize: 9, // ✅ 10 → 9
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: product.inStock ? onAddToCart : null,
                          child: Container(
                            width: 36, // ✅ 40 → 36
                            height: 36, // ✅ 40 → 36
                            decoration: BoxDecoration(
                              gradient: product.inStock ? AppColors.primaryGradient : null,
                              color: product.inStock ? null : AppColors.textLight.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.add_shopping_cart,
                              color: product.inStock ? Colors.white : AppColors.textLight,
                              size: 18, // ✅ 20 → 18
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// My Product Card
class _MyProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MyProductCard({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'uz_UZ');
    return '${formatter.format(price)} so\'m';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 80,
                height: 80,
                color: AppColors.softGreen,
                child: product.displayImage.isNotEmpty
                    ? Image.network(
                        product.displayImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppColors.textLight),
                      )
                    : const Icon(Icons.spa, color: AppColors.primaryGreen, size: 32),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(product.price),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: product.inStock ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.inStock ? 'Mavjud: ${product.stock_quantity}' : 'Tugagan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: product.inStock ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: product.isActive ? AppColors.accentBlue.withOpacity(0.1) : AppColors.textLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.isActive ? 'Faol' : 'Nofaol',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: product.isActive ? AppColors.accentBlue : AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit, color: AppColors.accentBlue, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
