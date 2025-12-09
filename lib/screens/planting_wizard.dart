import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class PlantingWizard extends StatefulWidget {
  const PlantingWizard({super.key});

  @override
  State<PlantingWizard> createState() => _PlantingWizardState();
}

class _PlantingWizardState extends State<PlantingWizard> {
  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMessage;
  String? _treeId;
  String? _wateringTaskId;
  CheckinResponse? _lastResponse;

  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // Take photo
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get location
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Joylashuvni aniqlab bo\'lmadi. GPS yoqilganligini tekshiring.';
        });
        return;
      }

      // Send to API
      final result = await api.analyzeCheckin(
        treeId: _currentStep == 2 ? _treeId : null,
        taskId: _currentStep == 2 ? _wateringTaskId : null,
        latitude: position.latitude,
        longitude: position.longitude,
        phaseHint: _currentStep == 1 ? 'planting' : 'watering',
        imageFile: File(photo.path),
      );

      if (!mounted) return;

      if (result.success && result.data != null) {
        final data = result.data!;
        _lastResponse = data;

        if (data.accepted) {
          if (_currentStep == 1) {
            // Step 1 success - move to step 2
            _treeId = data.treeId;

            // Find watering task in new_tasks
            if (data.newTasks != null) {
              for (var task in data.newTasks!) {
                if (task.type == 'watering') {
                  _wateringTaskId = task.id;
                  break;
                }
              }
            }

            setState(() {
              _currentStep = 2;
              _isLoading = false;
            });

            // Show GPT feedback
            _showFeedbackSheet(data.analysis?.comment ?? 'Ko\'chat muvaffaqiyatli ro\'yxatdan o\'tdi!');
          } else {
            // Step 2 success - show success and close
            setState(() => _isLoading = false);
            await _showSuccessDialog(data);
          }
        } else {
          // Rejected
          String errorMsg;
          if (data.errorCode == 'NOT_SEEDLING' || (data.errorCode?.contains('seedling') ?? false)) {
            errorMsg = 'Faqat yosh ko\'chat rasmini yuklang. Iltimos, qaytadan rasm oling.';
          } else if (data.errorCode == 'LOW_MOISTURE' || (data.errorCode?.contains('moisture') ?? false)) {
            errorMsg = 'Tuproq hali ham quruq. Ko\'proq sug\'orib, qaytadan rasm oling.';
          } else {
            errorMsg = data.message ?? data.analysis?.comment ?? 'Rasm qabul qilinmadi. Qaytadan urinib ko\'ring.';
          }

          setState(() {
            _isLoading = false;
            _errorMessage = errorMsg;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.error ?? 'Noma\'lum xatolik';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Xatolik yuz berdi: $e';
      });
    }
  }

  void _showFeedbackSheet(String comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('🤖', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'AI tahlili',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            Text(
              comment,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textMedium, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Davom etish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSuccessDialog(CheckinResponse data) async {
    final points = data.points?.awarded ?? 80;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('🎉', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text(
              'Tabriklaymiz!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ko\'chat ekish va birinchi sug\'orish muvaffaqiyatli yakunlandi!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textMedium, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Text(
                    '+$points ball',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (data.analysis?.comment != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Text('🤖', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text('AI tavsiyasi:', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.analysis!.comment!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Tayyor'),
            ),
          ),
        ],
      ),
    );

    // Refresh data
    if (mounted) {
      context.read<AppState>().loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yangi ko\'chat ekish'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_currentStep == 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Avval sug\'orish rasmini yuklashingiz kerak!'),
                  backgroundColor: AppColors.warning,
                ),
              );
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Progress indicator
              Row(
                children: [
                  _StepIndicator(step: 1, currentStep: _currentStep, label: '1'),
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _currentStep >= 2 ? AppColors.primaryGreen : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _StepIndicator(step: 2, currentStep: _currentStep, label: '2'),
                ],
              ),

              const SizedBox(height: 16),

              // Step labels
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ko\'chat ekish',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _currentStep == 1 ? FontWeight.w700 : FontWeight.w500,
                        color: _currentStep >= 1 ? AppColors.primaryGreen : AppColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Sug\'orish',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _currentStep == 2 ? FontWeight.w700 : FontWeight.w500,
                        color: _currentStep >= 2 ? AppColors.primaryGreen : AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Step content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        shape: BoxShape.circle,
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Center(
                        child: Text(
                          _currentStep == 1 ? '🌱' : '💧',
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                    const SizedBox(height: 32),

                    Text(
                      _currentStep == 1 ? 'Ko\'chat rasmini oling' : 'Sug\'orish rasmini oling',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: 12),

                    Text(
                      _currentStep == 1
                          ? 'Yangi ekgan ko\'chatingizni rasmga oling'
                          : 'Endi ko\'chatni sug\'orib, rasmga oling',
                      style: const TextStyle(fontSize: 16, color: AppColors.textMedium),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 150.ms),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ).animate().shake(duration: 300.ms),
                    ],
                  ],
                ),
              ),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _takePhoto,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt, size: 28),
                  label: Text(
                    _isLoading ? 'Tahlil qilinmoqda...' : 'Rasmga olish',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  final int currentStep;
  final String label;

  const _StepIndicator({required this.step, required this.currentStep, required this.label});

  @override
  Widget build(BuildContext context) {
    final isActive = currentStep >= step;
    final isCurrent = currentStep == step;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryGreen : AppColors.cardBackground,
        shape: BoxShape.circle,
        border: isCurrent
            ? Border.all(color: AppColors.primaryGreenLight, width: 3)
            : null,
        boxShadow: isCurrent ? AppColors.softShadow : null,
      ),
      child: Center(
        child: isActive && !isCurrent
            ? const Icon(Icons.check, color: Colors.white, size: 24)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.textLight,
                ),
              ),
      ),
    );
  }
}
