import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() { _phoneController.dispose(); _nameController.dispose(); _passwordController.dispose(); super.dispose(); }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Telefon raqamini kiriting';
    if (value.replaceAll(RegExp(r'[^\d+]'), '').length < 9) return 'Telefon raqami noto\'g\'ri';
    return null;
  }
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Ism-familyangizni kiriting';
    if (value.length < 2) return 'Ism kamida 2 ta belgidan iborat bo\'lishi kerak';
    return null;
  }
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Parolni kiriting';
    if (value.length < 6) return 'Parol kamida 6 ta belgidan iborat bo\'lishi kerak';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final appState = context.read<AppState>();
    final result = _isLogin
        ? await appState.login(_phoneController.text, _passwordController.text)
        : await appState.register(_phoneController.text, _nameController.text, _passwordController.text);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Xatolik yuz berdi'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.softGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppColors.softShadow),
                    child: ClipOval(child: Image.asset('assets/logo/greenify_logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('🌳', style: TextStyle(fontSize: 48))))),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  const Text('Greenify', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primaryGreen)).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 8),
                  Text(_isLogin ? 'Hisobingizga kiring' : 'Yangi hisob yarating', style: const TextStyle(fontSize: 16, color: AppColors.textMedium)).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 40),
                  TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, validator: _validatePhone, decoration: const InputDecoration(labelText: 'Telefon raqami', hintText: '+998 90 123 45 67', prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textLight))).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 16),
                  if (!_isLogin) ...[
                    TextFormField(controller: _nameController, validator: _validateName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ism-familya', hintText: 'Ism Familiya', prefixIcon: Icon(Icons.person_outline, color: AppColors.textLight))).animate().fadeIn(delay: 250.ms).slideX(begin: -0.1, end: 0),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(controller: _passwordController, obscureText: _obscurePassword, validator: _validatePassword, decoration: InputDecoration(labelText: 'Parol', prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textLight), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textLight), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)))).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isLogin ? 'Kirish' : 'Ro\'yxatdan o\'tish', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLogin ? 'Hisobingiz yo\'qmi?' : 'Hisobingiz bormi?', style: const TextStyle(color: AppColors.textMedium)),
                      TextButton(onPressed: () => setState(() { _isLogin = !_isLogin; _formKey.currentState?.reset(); }), child: Text(_isLogin ? 'Ro\'yxatdan o\'tish' : 'Kirish', style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700))),
                    ],
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
