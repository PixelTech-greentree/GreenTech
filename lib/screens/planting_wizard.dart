import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class PlantingWizard extends StatefulWidget {
  const PlantingWizard({super.key});
  @override State<PlantingWizard> createState() => _PlantingWizardState();
}

class _PlantingWizardState extends State<PlantingWizard> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;
  String? _treeId;
  CheckinResponse? _plantingResponse;
  CheckinResponse? _wateringResponse;

  Future<Position?> _getPosition() async {
    try { return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high); } catch (e) { setState(() => _error = 'Joylashuvni aniqlab bo\'lmadi'); return null; }
  }

  Future<void> _takePlantingPhoto() async {
    setState(() { _isLoading = true; _error = null; });
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
    if (photo == null) { setState(() => _isLoading = false); return; }
    final position = await _getPosition();
    if (position == null) { setState(() => _isLoading = false); return; }
    final result = await api.analyzeCheckin(latitude: position.latitude, longitude: position.longitude, phaseHint: 'planting', imageFile: File(photo.path));
    if (!mounted) return;
    if (result.success && result.data != null) {
      final resp = result.data!;
      if (resp.accepted && resp.treeId != null) { setState(() { _plantingResponse = resp; _treeId = resp.treeId; _currentStep = 1; _isLoading = false; }); }
      else { setState(() { _error = resp.message ?? resp.errorCode ?? 'Ko\'chat aniqlanmadi'; _isLoading = false; }); }
    } else { setState(() { _error = result.error ?? 'Xatolik yuz berdi'; _isLoading = false; }); }
  }

  Future<void> _takeWateringPhoto() async {
    if (_treeId == null) return;
    setState(() { _isLoading = true; _error = null; });
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
    if (photo == null) { setState(() => _isLoading = false); return; }
    final position = await _getPosition();
    if (position == null) { setState(() => _isLoading = false); return; }
    final result = await api.analyzeCheckin(treeId: _treeId, latitude: position.latitude, longitude: position.longitude, phaseHint: 'watering', imageFile: File(photo.path));
    if (!mounted) return;
    if (result.success && result.data != null) {
      final resp = result.data!;
      if (resp.accepted) { setState(() { _wateringResponse = resp; _currentStep = 2; _isLoading = false; }); await context.read<AppState>().loadAllData(); }
      else { setState(() { _error = resp.message ?? resp.errorCode ?? 'Sug\'orish tasdiqlanmadi'; _isLoading = false; }); }
    } else { setState(() { _error = result.error ?? 'Xatolik yuz berdi'; _isLoading = false; }); }
  }

  @override Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { if (_currentStep == 1) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avval sug\'orishni bajaring!'), backgroundColor: AppColors.warning)); return false; } return true; },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: _currentStep != 1 ? IconButton(icon: const Icon(Icons.close, color: AppColors.textDark), onPressed: () => Navigator.pop(context)) : null, automaticallyImplyLeading: false, title: const Text('Yangi ko\'chat ekish', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 18))),
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          _buildProgressIndicator(),
          const SizedBox(height: 32),
          Expanded(child: _currentStep == 0 ? _buildStep1() : _currentStep == 1 ? _buildStep2() : _buildSuccess()),
        ]))),
      ),
    );
  }

  Widget _buildProgressIndicator() => Row(children: [
    _StepCircle(number: 1, label: 'Ko\'chat ekish', isActive: _currentStep >= 0, isCompleted: _currentStep > 0),
    Expanded(child: Container(height: 2, color: _currentStep > 0 ? AppColors.primaryGreen : AppColors.textLight.withOpacity(0.3))),
    _StepCircle(number: 2, label: 'Sug\'orish', isActive: _currentStep >= 1, isCompleted: _currentStep > 1),
  ]);

  Widget _buildStep1() => Column(children: [
    Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.softGreen, shape: BoxShape.circle), child: const Center(child: Text('🌱', style: TextStyle(fontSize: 56)))).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
    const SizedBox(height: 24),
    const Text('Ko\'chat rasmini oling', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
    const SizedBox(height: 8),
    const Text('Yangi ekgan ko\'chatingizni rasmga oling', style: TextStyle(fontSize: 14, color: AppColors.textMedium), textAlign: TextAlign.center),
    if (_error != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color: AppColors.error, size: 20), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)))]))],
    const Spacer(),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: _isLoading ? null : _takePlantingPhoto, icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt, size: 24), label: Text(_isLoading ? 'Tekshirilmoqda...' : 'Rasmga olish'))),
  ]);

  Widget _buildStep2() => Column(children: [
    Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.1), shape: BoxShape.circle), child: const Center(child: Text('💧', style: TextStyle(fontSize: 56)))).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
    const SizedBox(height: 24),
    const Text('Sug\'orish majburiy!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
    const SizedBox(height: 8),
    const Text('Ko\'chatni sug\'oring va rasmga oling', style: TextStyle(fontSize: 14, color: AppColors.textMedium), textAlign: TextAlign.center),
    if (_plantingResponse?.aiFeedback?.comment != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Text('🤖', style: TextStyle(fontSize: 14)), SizedBox(width: 6), Text('AI:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]), const SizedBox(height: 6), Text(_plantingResponse!.aiFeedback!.comment!, style: const TextStyle(fontSize: 12, color: AppColors.textMedium))]))],
    if (_error != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color: AppColors.error, size: 20), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)))]))],
    const Spacer(),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: _isLoading ? null : _takeWateringPhoto, icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt, size: 24), label: Text(_isLoading ? 'Tekshirilmoqda...' : 'Sug\'orishni rasmga olish'))),
    const SizedBox(height: 12),
    const Text('⚠️ Sug\'ormasdan chiqib ketolmaysiz', style: TextStyle(fontSize: 12, color: AppColors.warning)),
  ]);

  Widget _buildSuccess() => SingleChildScrollView(child: Column(children: [
    const Text('🎉', style: TextStyle(fontSize: 72)).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
    const SizedBox(height: 16),
    const Text('Tabriklaymiz!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryGreen)),
    const SizedBox(height: 8),
    const Text('Ko\'chat muvaffaqiyatli ekildi va sug\'orildi', style: TextStyle(fontSize: 15, color: AppColors.textMedium), textAlign: TextAlign.center),
    if (_wateringResponse?.pointsEarned != null) ...[const SizedBox(height: 20), Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), decoration: BoxDecoration(gradient: AppColors.cardGradient, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('⭐', style: TextStyle(fontSize: 28)), const SizedBox(width: 10), Text('+${_wateringResponse!.pointsEarned} ball', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white))]))],
    // AI recommendations
    if (_wateringResponse?.aiFeedback != null) ...[
      const SizedBox(height: 24),
      Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Text('🤖', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('Greenify AI tavsiyalari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark))]),
        if (_wateringResponse!.aiFeedback!.comment != null) ...[const SizedBox(height: 12), Text(_wateringResponse!.aiFeedback!.comment!, style: const TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5))],
        if (_wateringResponse!.aiFeedback!.recommendations != null) ...[
          if (_wateringResponse!.aiFeedback!.recommendations!.immediateActions.isNotEmpty) ...[const SizedBox(height: 12), const Text('📋 Qilish kerak:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark)), const SizedBox(height: 8), ..._wateringResponse!.aiFeedback!.recommendations!.immediateActions.map((a) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• ', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)), Expanded(child: Text(a, style: const TextStyle(fontSize: 13, color: AppColors.textMedium)))])))],
          if (_wateringResponse!.aiFeedback!.recommendations!.wateringSchedule != null) ...[const SizedBox(height: 12), Row(children: [const Text('💧', style: TextStyle(fontSize: 16)), const SizedBox(width: 8), Text('Sug\'orish: ${_wateringResponse!.aiFeedback!.recommendations!.wateringSchedule}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark))])],
          if (_wateringResponse!.aiFeedback!.recommendations!.nextSteps.isNotEmpty) ...[const SizedBox(height: 12), const Text('📅 Keyingi qadamlar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark)), const SizedBox(height: 8), ..._wateringResponse!.aiFeedback!.recommendations!.nextSteps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('→ ', style: TextStyle(color: AppColors.accentBlue)), Expanded(child: Text(s, style: const TextStyle(fontSize: 13, color: AppColors.textMedium)))])))],
        ],
      ])),
    ],
    // Next tasks
    if (_wateringResponse?.nextTasks.isNotEmpty ?? false) ...[
      const SizedBox(height: 24),
      const Align(alignment: Alignment.centerLeft, child: Text('📋 Keyingi vazifalar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark))),
      const SizedBox(height: 12),
      ...(_wateringResponse!.nextTasks.map((t) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppColors.cardShadow), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(10)), child: Center(child: Text(t.type == 'watering' ? '💧' : '📷', style: const TextStyle(fontSize: 20)))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.type == 'watering' ? 'Sug\'orish' : 'Tekshirish', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)), if (t.dueDateFormatted != null) Text(t.dueDateFormatted!, style: const TextStyle(fontSize: 12, color: AppColors.textMedium))])), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.accentYellow.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('+${t.rewardPoints}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))])))),
    ],
    const SizedBox(height: 32),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Tayyor'))),
    const SizedBox(height: 20),
  ]));
}

class _StepCircle extends StatelessWidget {
  final int number; final String label; final bool isActive, isCompleted;
  const _StepCircle({required this.number, required this.label, required this.isActive, required this.isCompleted});
  @override Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: isCompleted ? AppColors.primaryGreen : isActive ? AppColors.primaryGreen : AppColors.textLight.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: isActive ? AppColors.primaryGreen : Colors.transparent, width: 2)), child: Center(child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 24) : Text('$number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isActive ? Colors.white : AppColors.textMedium)))),
    const SizedBox(height: 8),
    Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? AppColors.primaryGreen : AppColors.textMedium)),
  ]);
}
