import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';

class ImpactCard extends StatelessWidget {
  const ImpactCard({super.key});

  String _formatNumber(int number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(0)} mlrd';
    }
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)} mln';
    }
    if (number >= 1000) {
      return NumberFormat('#,###').format(number).replaceAll(',', ' ');
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.elevatedShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('🌍', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Text(
                    'Jamiyatga ta\'sirim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImpactItem(
                      icon: '🌱',
                      label: 'Mening daraxtlarim',
                      value: '${appState.totalTrees} ta',
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: _ImpactItem(
                      icon: '⭐',
                      label: 'Ballarim',
                      value: _formatNumber(appState.totalPoints),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white24),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ImpactItem(
                      icon: '🌳',
                      label: 'Umumiy daraxtlar',
                      value: _formatNumber(appState.globalTotalTrees),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: _ImpactItem(
                      icon: '👥',
                      label: 'Foydalanuvchilar',
                      value: _formatNumber(appState.globalTotalUsers),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImpactItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _ImpactItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
