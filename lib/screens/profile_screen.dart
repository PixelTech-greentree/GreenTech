import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final user = appState.demoUser;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
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
                              child: const Icon(Icons.settings_outlined, color: AppColors.textMedium, size: 22),
                            ),
                          ),

                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppColors.primaryGreen.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
                              ],
                            ),
                            child: const Center(child: Text('🌿', style: TextStyle(fontSize: 48))),
                          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                          const SizedBox(height: 16),

                          Text(user.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)).animate().fadeIn(delay: 100.ms),
                          const SizedBox(height: 4),
                          Text('@${user.username}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primaryGreen)).animate().fadeIn(delay: 150.ms),
                          const SizedBox(height: 4),
                          Text(user.phone, style: const TextStyle(fontSize: 14, color: AppColors.textMedium)).animate().fadeIn(delay: 200.ms),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _StatBox(icon: '✅', value: '${user.tasksCompletedToday}', label: 'Bugungi vazifalar')),
                      const SizedBox(width: 12),
                      Expanded(child: _StatBox(icon: '⭐', value: '${user.totalPoints}', label: 'Ballar')),
                      const SizedBox(width: 12),
                      Expanded(child: _StatBox(icon: '🌳', value: '${user.treesPlanted}', label: 'Daraxtlar')),
                    ],
                  ).animate().fadeIn(delay: 250.ms),
                ),

                _Section(
                  title: '🏆 Nishonlar',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: user.badges.map((badge) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.mintGreen, width: 1.5),
                        ),
                        child: Text(badge, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryGreenDark)),
                      );
                    }).toList(),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                _Section(
                  title: '🎁 Promo kodlar',
                  child: Column(
                    children: user.promoCodes.map((code) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.softGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryGreen, letterSpacing: 1.5)),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Nusxalandi: $code'),
                                    backgroundColor: AppColors.primaryGreen,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18, color: AppColors.primaryGreen),
                              label: const Text('Nusxalash', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ).animate().fadeIn(delay: 350.ms),

                _Section(
                  title: '📊 Rivojlanish',
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Daraja rivojlanishi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            Text('650 / 1000', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: const LinearProgressIndicator(
                            value: 0.65,
                            backgroundColor: AppColors.softGreen,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Keyingi darajaga 350 ball qoldi!', style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditProfile(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Profilni tahrirlash'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 450.ms),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Profilni tahrirlash', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 24),
              _buildTextField('Telefon raqami', '+998 90 123 45 67', Icons.phone_outlined),
              const SizedBox(height: 16),
              _buildTextField('Foydalanuvchi nomi', 'yashil_qahramon', Icons.alternate_email),
              const SizedBox(height: 16),
              _buildTextField('To\'liq ism', 'Shahzod Mirzayev', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField('Yangi parol', '', Icons.lock_outline, isPassword: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Profil muvaffaqiyatli yangilandi!'),
                        backgroundColor: AppColors.primaryGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: const Text('Saqlash'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String value, IconData icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: value),
          obscureText: isPassword,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textDark),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textLight, size: 22),
            hintText: isPassword ? '••••••••' : null,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _StatBox({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
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
}
