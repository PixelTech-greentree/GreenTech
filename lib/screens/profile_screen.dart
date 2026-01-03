import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/utils/app_colors.dart';
import '/services/app_state.dart';
import '/services/shop_state.dart';
import '/widgets/impact_card.dart';
import 'auth_screen.dart';
import 'cart_screen.dart';

class PromoCode {
  final String code;
  final String service;
  final DateTime expiryDate;
  final bool isActive;

  PromoCode({
    required this.code,
    required this.service,
    required this.expiryDate,
    this.isActive = true,
  });
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<PromoCode> _promoCodes = [
    PromoCode(
      code: 'GREENIFY2024',
      service: 'Yandex',
      expiryDate: DateTime.now().add(const Duration(days: 30)),
    ),
    PromoCode(
      code: 'UZUM15OFF',
      service: 'Uzum Market',
      expiryDate: DateTime.now().add(const Duration(days: 15)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadAllData());
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      return DateFormat('d MMMM yyyy', 'uz_UZ').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  String _formatPromoDate(DateTime date) {
    return DateFormat('dd.MM.yyyy', 'uz_UZ').format(date);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Chiqish'),
        content: const Text('Hisobdan chiqmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }

  void _copyPromoCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$code nusxalandi'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrdersScreen()),
    );
  }

  void _showPromotions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('🎉', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 12),
                  Text(
                    'Aksiyalar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _PromotionCard(
                    title: '50% chegirma',
                    description: 'Barcha o\'g\'itlarga maxsus chegirma',
                    emoji: '🌱',
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  _PromotionCard(
                    title: 'Tekin yetkazib berish',
                    description: '100,000 so\'mdan yuqori buyurtmalarga',
                    emoji: '🚚',
                    color: AppColors.accentBlue,
                  ),
                  const SizedBox(height: 12),
                  _PromotionCard(
                    title: '3 ta ol, 1 ta bepul',
                    description: 'Gorshoklar bo\'yicha',
                    emoji: '🪴',
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppState, ShopState>(
      builder: (context, appState, shopState, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () => appState.loadAllData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(gradient: AppColors.softGradient),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppColors.cardShadow,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.settings_outlined, color: AppColors.textMedium, size: 22),
                                  onPressed: () {},
                                ),
                              ),
                            ),
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGreen.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  )
                                ],
                              ),
                              child: ClipOval(
                                child: appState.userAvatarUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: appState.userAvatarUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => _buildDefaultAvatar(),
                                        errorWidget: (_, __, ___) => _buildDefaultAvatar(),
                                      )
                                    : _buildDefaultAvatar(),
                              ),
                            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                            const SizedBox(height: 16),
                            Text(
                              appState.userName.isNotEmpty ? appState.userName : 'Foydalanuvchi',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ).animate().fadeIn(delay: 100.ms),
                            const SizedBox(height: 4),
                            Text(
                              appState.userPhone,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ).animate().fadeIn(delay: 150.ms),
                            const SizedBox(height: 4),
                            Text(
                              'Ro\'yxatdan o\'tgan: ${_formatDate(appState.userCreatedAt)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                              ),
                            ).animate().fadeIn(delay: 200.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(child: _StatBox(icon: '⭐', value: '${appState.totalPoints}', label: 'Ballar')),
                        const SizedBox(width: 12),
                        Expanded(child: _StatBox(icon: '🌳', value: '${appState.totalTrees}', label: 'Daraxtlar')),
                        const SizedBox(width: 12),
                        Expanded(child: _StatBox(icon: '✅', value: '${appState.completedTasks}', label: 'Vazifalar')),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms),
                  
                  // Quick Actions
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ Tez harakatlar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                icon: '🛒',
                                label: 'Savat',
                                count: shopState.cartItemCount,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CartScreen()),  
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: '📦',
                                label: 'Buyurtmalar',
                                count: shopState.myOrders.length,
                                onTap: _showOrders,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionCard(
                                icon: '🎉',
                                label: 'Aksiyalar',
                                count: 3,
                                onTap: _showPromotions,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  // Promo Codes
                  _Section(
                    title: '🎫 Promokodlar',
                    child: Column(
                      children: _promoCodes.map((promo) {
                        final daysLeft = promo.expiryDate.difference(DateTime.now()).inDays;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryGreen.withOpacity(0.1),
                                AppColors.accentBlue.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primaryGreen.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          promo.service,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Amal qiladi: ${_formatPromoDate(promo.expiryDate)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: daysLeft > 7 ? AppColors.success : AppColors.warning,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$daysLeft kun',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _copyPromoCode(promo.code),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primaryGreen,
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          promo.code,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryGreen,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.copy,
                                        color: AppColors.primaryGreen,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: ImpactCard(),
                  ).animate().fadeIn(delay: 400.ms),

                  _Section(
                    title: '📊 Statistika',
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        children: [
                          _StatRow(label: 'Faol daraxtlar', value: '${appState.activeTrees}', icon: '🌱'),
                          const Divider(height: 24),
                          _StatRow(label: 'Jami sug\'orishlar', value: '${appState.totalWaterings}', icon: '💧'),
                          const Divider(height: 24),
                          _StatRow(label: 'Jami rasmlar', value: '${appState.totalCheckins}', icon: '📷'),
                          const Divider(height: 24),
                          _StatRow(label: 'G\'amxo\'rlik bahosi', value: '${appState.careScore.toStringAsFixed(0)}%', icon: '💚'),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 450.ms),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(Icons.logout, color: AppColors.error),
                        label: const Text(
                          'Chiqish',
                          style: TextStyle(color: AppColors.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar() => Image.asset(
        'assets/logo/greenify_logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.softGreen,
          child: const Center(child: Text('🌿', style: TextStyle(fontSize: 48))),
        ),
      );
}

class _StatBox extends StatelessWidget {
  final String icon, value, label;
  const _StatBox({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
          ],
        ),
      );
}

class _ActionCard extends StatelessWidget {
  final String icon, label;
  final int count;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 32)),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$count',
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
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PromotionCard extends StatelessWidget {
  final String title, description, emoji;
  final Color color;

  const _PromotionCard({
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StatRow extends StatelessWidget {
  final String label, value, icon;
  const _StatRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textMedium))),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ],
      );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

// ========================================
// ORDERS SCREEN
// ========================================

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  String _formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'uz_UZ');
    return '${formatter.format(price)} so\'m';
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm', 'uz_UZ').format(date);
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
    return Consumer<ShopState>(
      builder: (context, shopState, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Buyurtmalarim',
              style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: shopState.myOrders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📦', style: TextStyle(fontSize: 64)),
                      SizedBox(height: 16),
                      Text(
                        'Buyurtmalar yo\'q',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: shopState.myOrders.length,
                  itemBuilder: (context, index) {
                    final order = shopState.myOrders[index];
                    return Container(
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
                                  'Buyurtma #${order.id.substring(0, 8)}',
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
                            _formatDate(order.date),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                            ),
                          ),
                          
                          // Note (agar bo'lsa)
                          if (order.note != null && order.note!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.softGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.note, size: 16, color: AppColors.textMedium),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      order.note!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textDark,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          // Items with status
                          ...order.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item.item.name} x${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Status badge
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
                                    ),
                                    Text(
                                      _formatPrice(item.totalPrice),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Jami:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                _formatPrice(order.total),
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
                    );
                  },
                ),
        );
      },
    );
  }
}