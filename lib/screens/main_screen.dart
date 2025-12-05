import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'rating_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final screens = [
          const HomeScreen(),
          const TasksScreen(),
          const RatingScreen(),
          const ProfileScreen(),
        ];
        
        return Scaffold(
          body: IndexedStack(
            index: appState.currentIndex,
            children: screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Asosiy',
                      isSelected: appState.currentIndex == 0,
                      onTap: () => appState.setCurrentIndex(0),
                    ),
                    _NavItem(
                      icon: Icons.check_box_outlined,
                      activeIcon: Icons.check_box,
                      label: 'Vazifalar',
                      isSelected: appState.currentIndex == 1,
                      onTap: () => appState.setCurrentIndex(1),
                    ),
                    _NavItem(
                      icon: Icons.emoji_events_outlined,
                      activeIcon: Icons.emoji_events,
                      label: 'Reyting',
                      isSelected: appState.currentIndex == 2,
                      onTap: () => appState.setCurrentIndex(2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Profil',
                      isSelected: appState.currentIndex == 3,
                      onTap: () => appState.setCurrentIndex(3),
                    ),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.softGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.primaryGreen : AppColors.textLight,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryGreen : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
