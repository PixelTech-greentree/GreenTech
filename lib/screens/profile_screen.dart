import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';
import '../widgets/impact_card.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadAllData()); }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try { return DateFormat('d MMMM yyyy', 'uz_UZ').format(DateTime.parse(dateStr)); } catch (e) { return dateStr; }
  }

  void _showLogoutDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Chiqish'), content: const Text('Hisobdan chiqmoqchimisiz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
        ElevatedButton(onPressed: () async { Navigator.pop(ctx); await context.read<AppState>().logout(); if (!mounted) return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Chiqish')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, child) {
      return Scaffold(backgroundColor: AppColors.background, body: RefreshIndicator(
        onRefresh: () => appState.loadAllData(),
        child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: Column(children: [
          Container(decoration: const BoxDecoration(gradient: AppColors.softGradient), child: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            Align(alignment: Alignment.topRight, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppColors.cardShadow), child: IconButton(icon: const Icon(Icons.settings_outlined, color: AppColors.textMedium, size: 22), onPressed: () {}))),
            Container(width: 110, height: 110, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)]), child: ClipOval(child: appState.userAvatarUrl != null ? CachedNetworkImage(imageUrl: appState.userAvatarUrl!, fit: BoxFit.cover, placeholder: (_, __) => _buildDefaultAvatar(), errorWidget: (_, __, ___) => _buildDefaultAvatar()) : _buildDefaultAvatar())).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(appState.userName.isNotEmpty ? appState.userName : 'Foydalanuvchi', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 4),
            Text(appState.userPhone, style: const TextStyle(fontSize: 16, color: AppColors.primaryGreen, fontWeight: FontWeight.w500)).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 4),
            Text('Ro\'yxatdan o\'tgan: ${_formatDate(appState.userCreatedAt)}', style: const TextStyle(fontSize: 13, color: AppColors.textMedium)).animate().fadeIn(delay: 200.ms),
          ])))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
            Expanded(child: _StatBox(icon: '⭐', value: '${appState.totalPoints}', label: 'Ballar')),
            const SizedBox(width: 12),
            Expanded(child: _StatBox(icon: '🌳', value: '${appState.totalTrees}', label: 'Daraxtlar')),
            const SizedBox(width: 12),
            Expanded(child: _StatBox(icon: '✅', value: '${appState.completedTasks}', label: 'Vazifalar')),
          ]).animate().fadeIn(delay: 250.ms)),
          const Padding(padding: EdgeInsets.all(20), child: ImpactCard()).animate().fadeIn(delay: 300.ms),
          _Section(title: '📊 Statistika', child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: AppColors.cardShadow), child: Column(children: [
            _StatRow(label: 'Faol daraxtlar', value: '${appState.activeTrees}', icon: '🌱'),
            const Divider(height: 24),
            _StatRow(label: 'Jami sug\'orishlar', value: '${appState.totalWaterings}', icon: '💧'),
            const Divider(height: 24),
            _StatRow(label: 'Jami rasmlar', value: '${appState.totalCheckins}', icon: '📷'),
            const Divider(height: 24),
            _StatRow(label: 'G\'amxo\'rlik bahosi', value: '${appState.careScore.toStringAsFixed(0)}%', icon: '💚'),
          ]))).animate().fadeIn(delay: 350.ms),
          Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, height: 56, child: OutlinedButton.icon(onPressed: _showLogoutDialog, icon: const Icon(Icons.logout, color: AppColors.error), label: const Text('Chiqish', style: TextStyle(color: AppColors.error)), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))))).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 80),
        ])),
      ));
    });
  }
  Widget _buildDefaultAvatar() => Image.asset('assets/logo/greenify_logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.softGreen, child: const Center(child: Text('🌿', style: TextStyle(fontSize: 48)))));
}

class _StatBox extends StatelessWidget {
  final String icon, value, label;
  const _StatBox({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: AppColors.cardShadow), child: Column(children: [Text(icon, style: const TextStyle(fontSize: 26)), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMedium))]));
}

class _StatRow extends StatelessWidget {
  final String label, value, icon;
  const _StatRow({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [Text(icon, style: const TextStyle(fontSize: 20)), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textMedium))), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark))]);
}

class _Section extends StatelessWidget {
  final String title; final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)), const SizedBox(height: 14), child]));
}
