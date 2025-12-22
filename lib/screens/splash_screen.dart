import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';
import 'auth_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  bool _showLogo = false;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _videoController = VideoPlayerController.asset('assets/intro/greenify_intro.mp4');
      await _videoController!.initialize();
      await _videoController!.setLooping(false);
      await _videoController!.play();
      setState(() {});
      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration) _onVideoEnd();
      });
      Future.delayed(const Duration(seconds: 6), () { if (mounted && !_showLogo) _onVideoEnd(); });
    } catch (e) {
      setState(() => _videoError = true);
      _onVideoEnd();
    }
  }

  void _onVideoEnd() {
    if (!mounted) return;
    setState(() => _showLogo = true);
    Future.delayed(const Duration(milliseconds: 1500), _checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final appState = context.read<AppState>();
    final isLoggedIn = await appState.checkAuth();
    if (!mounted) return;
    if (isLoggedIn) {
      await appState.loadAllData();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController != null && _videoController!.value.isInitialized && !_videoError)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                ),
              ),
            ),
          if (_showLogo)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.5)],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primaryGreen.withOpacity(0.4), blurRadius: 30, spreadRadius: 10)],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/logo/greenify_logo.png', fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Text('🌳', style: TextStyle(fontSize: 64)))),
                        ),
                      ).animate().scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.elasticOut).fadeIn(duration: 400.ms),
                      const SizedBox(height: 32),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF81C784), Color(0xFF4CAF50), Color(0xFF66BB6A)]).createShader(bounds),
                        child: const Text('Greenify', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
                      ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                      const SizedBox(height: 12),
                      const Text('Tabiatni asrang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white70, letterSpacing: 1)).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                      const SizedBox(height: 60),
                      SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)))).animate().fadeIn(delay: 600.ms),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
