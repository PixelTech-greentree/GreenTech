import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../services/shop_state.dart';
import '../services/app_state.dart'; // ✅ AUTH UCHUN
import '../models/shop_models.dart';

class OrderNotificationsScreen extends StatefulWidget {
  const OrderNotificationsScreen({super.key});

  @override
  State<OrderNotificationsScreen> createState() => _OrderNotificationsScreenState();
}

class _OrderNotificationsScreenState extends State<OrderNotificationsScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver  {
  late TabController _tabController;

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
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final shopState = context.read<ShopState>();
    await Future.wait([
      shopState.loadNotifications(),
      shopState.loadMyOrders(),
      shopState.loadSellerOrders(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopState>(
      builder: (context, shopState, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                const Text(
                  '🔔 Bildirishnomalar',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                if (shopState.unreadNotificationCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${shopState.unreadNotificationCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          body: Column(
            children: [
              // Tab bar
              Container(
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
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMedium,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_active, size: 18),
                          const SizedBox(width: 6),
                          const Text('Yangi'),
                          if (shopState.unreadNotificationCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${shopState.unreadNotificationCount}',
                                style: const TextStyle(fontSize: 9, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2, size: 18),
                          SizedBox(width: 6),
                          Text('Buyurtmalarim'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _NotificationsTab(
                      notifications: shopState.notifications,
                      isLoading: shopState.isLoadingNotifications,
                      onRefresh: _loadData,
                      onMarkRead: (id) => shopState.markNotificationRead(id),
                      sellerOrders: shopState.sellerOrders,
                    ),
                    _OrdersTab(
                      myOrders: shopState.myOrders,
                      sellerOrders: shopState.sellerOrders,
                      isLoading: shopState.isLoadingOrders,
                      onRefresh: _loadData,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========================================
// NOTIFICATIONS TAB
// ========================================

class _NotificationsTab extends StatelessWidget {
  final List<OrderNotificationModel> notifications;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Function(String) onMarkRead;
  final List<OrderModel> sellerOrders;

  const _NotificationsTab({
    required this.notifications,
    required this.isLoading,
    required this.onRefresh,
    required this.onMarkRead,
    required this.sellerOrders,
  });

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} daqiqa oldin';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} soat oldin';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} kun oldin';
      } else {
        return DateFormat('dd.MM.yyyy HH:mm', 'uz_UZ').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'uz_UZ');
    return '${formatter.format(price)} so\'m';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.softGreen,
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('🔔', style: TextStyle(fontSize: 48))),
            ),
            const SizedBox(height: 20),
            const Text(
              'Yangi bildirishnomalar yo\'q',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMedium),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buyurtmalar tushganda bu yerda ko\'rinadi',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return GestureDetector(
            onTap: () {
              if (!notification.isRead) {
                onMarkRead(notification.id);
              }
              
              // Order topish
              final order = sellerOrders.firstWhere(
                (o) => o.id == notification.orderId,
                orElse: () => sellerOrders.isNotEmpty ? sellerOrders.first : OrderModel(
                  id: notification.orderId,
                  buyerId: notification.buyerId,
                  buyerName: notification.buyerName ?? '',
                  buyerPhone: notification.buyerPhone ?? '',
                  totalAmount: notification.orderTotal,
                  items: [],
                ),
              );
              
              // ✅ SELLER VIEW bilan ochish
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailScreen(
                    order: order,
                    isSellerView: true, // ✅ MUHIM!
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: notification.isRead ? Colors.white : AppColors.softGreen,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppColors.cardShadow,
                border: notification.isRead
                    ? null
                    : Border.all(color: AppColors.primaryGreen.withOpacity(0.3), width: 2),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: notification.isRead
                          ? AppColors.textLight.withOpacity(0.1)
                          : AppColors.primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        notification.isRead ? '📦' : '🛒',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Yangi buyurtma!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${notification.buyerName ?? 'Xaridor'} • ${notification.itemCount} ta mahsulot',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              _formatPrice(notification.orderTotal),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(notification.createdAt),
                              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.05, end: 0),
          );
        },
      ),
    );
  }
}

// ========================================
// ORDERS TAB
// ========================================

class _OrdersTab extends StatefulWidget {
  final List<OrderModel> myOrders;
  final List<OrderModel> sellerOrders;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _OrdersTab({
    required this.myOrders,
    required this.sellerOrders,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  bool _showMyOrders = true;

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'uz_UZ');
    return '${formatter.format(price)} so\'m';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      return DateFormat('dd.MM.yyyy HH:mm', 'uz_UZ').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    
    final orders = _showMyOrders ? widget.myOrders : widget.sellerOrders;
    
    return Column(
      children: [
        // Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showMyOrders = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _showMyOrders ? AppColors.primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Center(
                      child: Text(
                        'Mening buyurtmalarim',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _showMyOrders ? Colors.white : AppColors.textMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showMyOrders = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_showMyOrders ? AppColors.primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Center(
                      child: Text(
                        'Kelgan buyurtmalar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: !_showMyOrders ? Colors.white : AppColors.textMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Orders list
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📦', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text(
                        _showMyOrders ? 'Buyurtmalar yo\'q' : 'Kelgan buyurtmalar yo\'q',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return GestureDetector(
                        onTap: () {
                          // ✅ MODE ga qarab ochish
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailScreen(
                                order: order,
                                isSellerView: !_showMyOrders, // ✅ MUHIM!
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Buyurtma #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDate(order.createdAt),
                                style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                              ),
                              
                              // Buyer info (for seller view)
                              if (!_showMyOrders) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 16, color: AppColors.textLight),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${order.buyerName} • ${order.buyerPhone}',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                                    ),
                                  ],
                                ),
                              ],
                              
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              
                              // Items preview
                              ...order.items.take(2).map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.productName} x${item.quantity}',
                                        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                                      ),
                                    ),
                                    // Status chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(item.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.statusText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(item.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                              
                              if (order.items.length > 2)
                                Text(
                                  '+${order.items.length - 2} ta boshqa...',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                ),
                              
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              
                              // Total
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Jami:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  Text(
                                    _formatPrice(order.totalAmount),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'confirmed': return AppColors.accentBlue;
      case 'shipped': return Colors.purple;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textMedium;
    }
  }
}

// ========================================
// ORDER DETAIL SCREEN
// ========================================

// ========================================
// ORDER DETAIL SCREEN - STATEFUL
// ========================================

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  final bool isSellerView;

  const OrderDetailScreen({
    Key? key,
    required this.order,
    this.isSellerView = false,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late OrderModel _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  // ✅ REFRESH QILISH
  Future<void> _refreshOrder() async {
    final shopState = Provider.of<ShopState>(context, listen: false);
    
    // Orderlarni qayta yuklash
    if (widget.isSellerView) {
      await shopState.loadSellerOrders();
      // Yangi order topish
      final updatedOrder = shopState.sellerOrders.firstWhere(
        (o) => o.id == _currentOrder.id,
        orElse: () => _currentOrder,
      );
      setState(() {
        _currentOrder = updatedOrder;
      });
    } else {
      await shopState.loadMyOrders();
      final updatedOrder = shopState.myOrders.firstWhere(
        (o) => o.id == _currentOrder.id,
        orElse: () => _currentOrder,
      );
      setState(() {
        _currentOrder = updatedOrder;
      });
    }
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'uz_UZ');
    return '${formatter.format(price)} so\'m';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      return DateFormat('dd.MM.yyyy HH:mm', 'uz_UZ').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'confirmed': return AppColors.accentBlue;
      case 'shipped': return Colors.purple;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Buyurtma tafsilotlari',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        // ✅ REFRESH TUGMASI
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
            onPressed: _refreshOrder,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrder, // ✅ PULL-TO-REFRESH
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buyurtma #${_currentOrder.id.substring(0, 8)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sana: ${_formatDate(_currentOrder.createdAt)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textMedium),
                    ),
                    if (_currentOrder.note != null && _currentOrder.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.note, size: 16, color: AppColors.textLight),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _currentOrder.note!,
                              style: const TextStyle(fontSize: 13, color: AppColors.textMedium, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Buyer info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xaridor ma\'lumotlari',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20, color: AppColors.primaryGreen),
                        const SizedBox(width: 10),
                        Text(_currentOrder.buyerName, style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 20, color: AppColors.primaryGreen),
                        const SizedBox(width: 10),
                        Text(_currentOrder.buyerPhone, style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Items header
              const Text(
                'Mahsulotlar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),

              // Items list
              ..._currentOrder.items.map((item) => _buildItemCard(context, item)).toList(),

              const SizedBox(height: 16),

              // Total
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'JAMI SUMMA:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      _formatPrice(_currentOrder.totalAmount),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, OrderItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product info
          Text(
            item.productName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatPrice(item.productPrice)} x ${item.quantity} = ${_formatPrice(item.subtotal)}',
            style: const TextStyle(fontSize: 14, color: AppColors.textMedium),
          ),
          const SizedBox(height: 4),
          Text(
            'Sotuvchi: ${item.sellerName}',
            style: const TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
          const SizedBox(height: 12),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(item.status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getStatusIcon(item.status), size: 16, color: _getStatusColor(item.status)),
                const SizedBox(width: 6),
                Text(
                  item.statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _getStatusColor(item.status),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          _buildActionButtons(context, item),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_empty;
      case 'confirmed': return Icons.check_circle_outline;
      case 'shipped': return Icons.local_shipping;
      case 'completed': return Icons.done_all;
      case 'cancelled': return Icons.cancel;
      default: return Icons.info_outline;
    }
  }

  Widget _buildActionButtons(BuildContext context, OrderItemModel item) {
  final appState = Provider.of<AppState>(context, listen: false);
  final currentUserId = appState.userId;
  final isMySale = item.sellerId == currentUserId;
  final isBuyer = _currentOrder.buyerId == currentUserId;
  
  // ========================================
  // BUYER (XARIDOR) UCHUN
  // ========================================
  if (isBuyer && !widget.isSellerView) {
    // ✅ Shipped bo'lsa - "Qabul qildim" va "Qaytarish" tugmalari
    if (item.status == 'shipped') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateItemStatus(context, item.id, item.sellerId, 'completed'),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Qabul qildim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showRejectDialog(context, item),
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Qaytarish'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }
    
    // Boshqa statuslar uchun faqat ko'rsatish
    return _buildStatusOnlyView(item);
  }
  
  // ========================================
  // SELLER (SOTUVCHI) UCHUN
  // ========================================
  if (!widget.isSellerView || !isMySale) {
    return _buildStatusOnlyView(item);
  }
  
  switch (item.status) {
    case 'pending':
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateItemStatus(context, item.id, item.sellerId, 'confirmed'),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Tasdiqlash'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _updateItemStatus(context, item.id, item.sellerId, 'cancelled'),
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Bekor'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );

    case 'confirmed':
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateItemStatus(context, item.id, item.sellerId, 'shipped'),
          icon: const Icon(Icons.local_shipping, size: 18),
          label: const Text('Jo\'natish'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

    case 'shipped':
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.3), width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, color: Colors.purple, size: 20),
            SizedBox(width: 8),
            Text(
              '📦 Xaridor qabul qilishini kutmoqda...',
              style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      );

    case 'rejected':
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return, color: AppColors.warning, size: 20),
            SizedBox(width: 8),
            Text(
              '🔄 Xaridor qaytardi',
              style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      );

    case 'completed':
    case 'cancelled':
      return _buildStatusOnlyView(item);

    default:
      return const SizedBox.shrink();
  }
}

// ✅ REJECT DIALOG
void _showRejectDialog(BuildContext context, OrderItemModel item) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
          SizedBox(width: 12),
          Text('Mahsulotni qaytarasizmi?'),
        ],
      ),
      content: const Text(
        'Mahsulot sifati yoki boshqa sabablar bilan qaytarmoqchimisiz?',
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Yo\'q'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _updateItemStatus(context, item.id, item.sellerId, 'rejected');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Ha, qaytarish'),
        ),
      ],
    ),
  );
}

  Widget _buildStatusOnlyView(OrderItemModel item) {
  if (item.status == 'completed') {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          SizedBox(width: 8),
          Text(
            '✅ Yakunlangan',
            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  if (item.status == 'cancelled') {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3), width: 2),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel, color: AppColors.error, size: 20),
          SizedBox(width: 8),
          Text(
            '❌ Bekor qilingan',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  // ✅ REJECTED STATUS
  if (item.status == 'rejected') {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 2),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_return, color: AppColors.warning, size: 20),
          SizedBox(width: 8),
          Text(
            '🔄 Qaytarilgan',
            style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _getStatusColor(item.status).withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_getStatusIcon(item.status), 
             color: _getStatusColor(item.status), 
             size: 20),
        const SizedBox(width: 8),
        Text(
          'Status: ${item.statusText}',
          style: TextStyle(
            color: _getStatusColor(item.status),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

  // ✅ STATUS YANGILANISHI + REFRESH
  Future<void> _updateItemStatus(BuildContext context, String itemId, String sellerId, String newStatus) async {
    final shopState = Provider.of<ShopState>(context, listen: false);

    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    final result = await shopState.updateOrderItemStatus(itemId, sellerId, newStatus);

    // Close loading
    if (context.mounted) Navigator.of(context).pop();

    if (result.success) {
      // ✅ REFRESH QILISH
      await _refreshOrder();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Status yangilandi!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Xatolik: ${result.error}')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}