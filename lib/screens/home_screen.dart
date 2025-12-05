import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)} mln';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)} ming';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppColors.softGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Salom, ${appState.demoUser.fullName.split(' ').first}! 👋',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Bugun daraxt ekamizmi?',
                              style: TextStyle(fontSize: 15, color: AppColors.textMedium),
                            ),
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: const Icon(Icons.notifications_outlined, color: AppColors.textMedium),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms),
                    
                    const SizedBox(height: 24),
                    
                    // Map Preview
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [AppColors.softGreen, AppColors.mintGreen.withOpacity(0.5)],
                        ),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3), width: 2),
                                  ),
                                  child: const Icon(Icons.location_on, color: AppColors.primaryGreen, size: 30),
                                ),
                                const SizedBox(height: 8),
                                const Text('2 km radius', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🌳', style: TextStyle(fontSize: 14)),
                                  SizedBox(width: 4),
                                  Text('24 ta daraxt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    appState.locationGranted ? Icons.check_circle : Icons.error_outline,
                                    size: 16,
                                    color: appState.locationGranted ? AppColors.success : AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    appState.locationGranted ? 'Joylashuv aniqlandi' : 'Joylashuv aniqlanmadi',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    
                    const SizedBox(height: 28),
                    
                    // Stats Title
                    const Text(
                      'Jamiyat ta\'siri',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ).animate().fadeIn(delay: 200.ms),
                    
                    const SizedBox(height: 16),
                    
                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: '🌳',
                            value: _formatNumber(appState.totalTrees),
                            label: 'Ekilgan daraxtlar',
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: '👥',
                            value: _formatNumber(appState.totalMembers),
                            label: 'A\'zolar',
                            color: AppColors.accentBlue,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms),
                    
                    const SizedBox(height: 12),
                    
                    _StatCard(
                      icon: '💰',
                      value: '${_formatNumber(appState.totalFunds)} so\'m',
                      label: 'Yig\'ilgan mablag\'',
                      color: AppColors.accentOrange,
                      isWide: true,
                    ).animate().fadeIn(delay: 400.ms),
                    
                    const SizedBox(height: 28),
                    
                    // Quick Actions
                    const Text(
                      'Tezkor amallar',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ).animate().fadeIn(delay: 500.ms),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: '🌱',
                            label: 'Daraxt ekish',
                            isPrimary: true,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: '💚',
                            label: 'Xayriya',
                            isPrimary: false,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 600.ms),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  final bool isWide;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWide ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: isWide
          ? Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textMedium)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(height: 14),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
              ],
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppColors.primaryGradient : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isPrimary
              ? [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
              : AppColors.cardShadow,
          border: isPrimary ? null : Border.all(color: AppColors.mintGreen, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
