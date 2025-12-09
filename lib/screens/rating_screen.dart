import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  String _selectedRange = '7d';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  Future<void> _loadRating() async {
    setState(() => _isLoading = true);
    await context.read<AppState>().loadRating(range: _selectedRange);
    if (mounted) setState(() => _isLoading = false);
  }

  void _onRangeChanged(String range) {
    setState(() => _selectedRange = range);
    _loadRating();
  }

  String _getRangeLabel(String range) {
    switch (range) {
      case '7d':
        return 'Oxirgi 7 kun';
      case '30d':
        return 'Oxirgi 30 kun';
      case 'all':
        return 'Barcha vaqt';
      default:
        return range;
    }
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
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reyting',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
                            ),
                            Text(
                              'Eng faol ishtirokchilar',
                              style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                            ),
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

                // Range selector
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: ['7d', '30d', 'all'].map((range) {
                      final isSelected = _selectedRange == range;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onRangeChanged(range),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected ? AppColors.cardShadow : null,
                            ),
                            child: Text(
                              _getRangeLabel(range),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppColors.primaryGreen : AppColors.textMedium,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 20),

                // Rating list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                      : appState.ratingUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🏆', style: TextStyle(fontSize: 64)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Reyting bo\'sh',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Hali hech kim vazifa bajarmagan',
                                    style: TextStyle(color: AppColors.textLight),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadRating,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: appState.ratingUsers.length,
                                itemBuilder: (context, index) {
                                  final user = appState.ratingUsers[index];
                                  final isCurrentUser = user.id == appState.userId;
                                  return _RankCard(
                                    user: user,
                                    isCurrentUser: isCurrentUser,
                                  ).animate().fadeIn(delay: Duration(milliseconds: 50 * index));
                                },
                              ),
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
  final RatingUserModel user;
  final bool isCurrentUser;

  const _RankCard({required this.user, required this.isCurrentUser});

  String get _rankEmoji {
    switch (user.rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  Color get _rankColor {
    switch (user.rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTopThree = user.rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.softGreen : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
        border: isTopThree
            ? Border.all(color: _rankColor.withOpacity(0.4), width: 2)
            : isCurrentUser
                ? Border.all(color: AppColors.primaryGreen, width: 2)
                : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 48,
            child: Center(
              child: isTopThree
                  ? Text(_rankEmoji, style: const TextStyle(fontSize: 28))
                  : Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '#${user.rank}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMedium),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isTopThree ? _rankColor.withOpacity(0.15) : AppColors.softGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isTopThree ? _rankColor : AppColors.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          
          // Name & tasks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Siz',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.taskCount} ta vazifa',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
          
          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isTopThree ? _rankColor.withOpacity(0.1) : AppColors.accentYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '${user.pointsSum}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isTopThree ? _rankColor : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
