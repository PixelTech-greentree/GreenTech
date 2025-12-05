import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)} mln';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)} ming';
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jamiyat reytingi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                            SizedBox(height: 4),
                            Text('Kim ko\'proq hissa qo\'shmoqda?', style: TextStyle(fontSize: 15, color: AppColors.textMedium)),
                          ],
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: const Center(child: Text('🏆', style: TextStyle(fontSize: 24))),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.cardShadow,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    labelColor: AppColors.primaryGreen,
                    unselectedLabelColor: AppColors.textMedium,
                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '💰 Top homiylar'),
                      Tab(text: '🌳 Top ekuvchilar'),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 20),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: appState.donationRanking.length,
                        itemBuilder: (context, index) {
                          final item = appState.donationRanking[index];
                          return _RankCard(
                            rank: item['rank'],
                            name: item['name'],
                            avatar: item['avatar'],
                            value: '${_formatAmount(item['amount'])} so\'m',
                          ).animate().fadeIn(delay: Duration(milliseconds: 50 * index));
                        },
                      ),
                      ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: appState.activeRanking.length,
                        itemBuilder: (context, index) {
                          final item = appState.activeRanking[index];
                          return _RankCard(
                            rank: item['rank'],
                            name: item['name'],
                            avatar: item['avatar'],
                            value: '${item['trees']} ta daraxt',
                          ).animate().fadeIn(delay: Duration(milliseconds: 50 * index));
                        },
                      ),
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
}

class _RankCard extends StatelessWidget {
  final int rank;
  final String name;
  final String avatar;
  final String value;

  const _RankCard({
    required this.rank,
    required this.name,
    required this.avatar,
    required this.value,
  });

  String get _rankEmoji {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '#$rank';
    }
  }

  Color get _rankColor {
    switch (rank) {
      case 1: return const Color(0xFFFFD700);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTopThree = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
        border: isTopThree ? Border.all(color: _rankColor.withOpacity(0.3), width: 2) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: rank <= 3
                  ? Text(_rankEmoji, style: const TextStyle(fontSize: 26))
                  : Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('#$rank', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isTopThree ? _rankColor.withOpacity(0.15) : AppColors.softGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(avatar, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isTopThree ? _rankColor.withOpacity(0.1) : AppColors.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isTopThree ? _rankColor : AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }
}
