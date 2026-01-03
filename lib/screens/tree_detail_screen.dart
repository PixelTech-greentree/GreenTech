import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class TreeDetailScreen extends StatefulWidget {
  final String treeId;
  const TreeDetailScreen({super.key, required this.treeId});
  @override State<TreeDetailScreen> createState() => _TreeDetailScreenState();
}

class _TreeDetailScreenState extends State<TreeDetailScreen> {
  TreeModel? _tree;
  List<HealthHistoryItem> _history = [];
  bool _isLoading = true;
  String? _error;

  @override void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    final treeResult = await api.getTreeFull(widget.treeId);
    if (treeResult.success && treeResult.data != null) {
      _tree = treeResult.data;
      final historyResult = await api.getTreeHealthHistory(widget.treeId);
      if (historyResult.success && historyResult.data != null) _history = historyResult.data!;
    } else { _error = treeResult.error; }
    if (mounted) setState(() => _isLoading = false);
  }

  Color _healthColor(String? h) { switch(h) { case 'healthy': return AppColors.success; case 'stressed': return AppColors.warning; case 'critical': return AppColors.error; default: return AppColors.textMedium; } }
  String _healthText(String? h) { switch(h) { case 'healthy': return 'Sog\'lom'; case 'stressed': return 'Stressda'; case 'critical': return 'Kritik'; default: return h ?? 'Noma\'lum'; } }
  String _trendIcon(String? t) { switch(t) { case 'improving': return '📈'; case 'stable': return '➡️'; case 'declining': return '📉'; default: return ''; } }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark), onPressed: () => Navigator.pop(context)), title: Text(_tree?.name ?? 'Daraxt', style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700))),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)) : _error != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: AppColors.error), const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: AppColors.textMedium)), const SizedBox(height: 24), ElevatedButton(onPressed: _loadData, child: const Text('Qayta urinish'))])) : RefreshIndicator(onRefresh: _loadData, child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Photo card
        Container(
          height: 200, width: double.infinity, decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.cardShadow),
          child: ClipRRect(borderRadius: BorderRadius.circular(24), child: _tree?.latestPhotoUrl != null ? Image.network('${api.baseUrl}${_tree!.latestPhotoUrl}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder()) : _buildPlaceholder()),
        ).animate().fadeIn(),
        const SizedBox(height: 20),
        // Basic info
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow), child: Column(children: [
          Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(14)), child: Center(child: Text(TreePhases.getIcon(_tree?.phase ?? ''), style: const TextStyle(fontSize: 28)))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_tree?.name ?? 'Daraxt #${widget.treeId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Row(children: [_Chip(label: TreePhases.getName(_tree?.phase ?? ''), color: AppColors.primaryGreen), const SizedBox(width: 8), _Chip(label: _tree?.status == 'active' ? 'Faol' : _tree?.status ?? '', color: _tree?.status == 'active' ? AppColors.success : AppColors.error)]),
            ])),
          ]),
          const SizedBox(height: 20), const Divider(),
          _InfoRow(icon: '📅', label: 'Ekilgan sana', value: _tree?.plantedDateFormatted ?? '-'),
          _InfoRow(icon: '⏱', label: 'Yoshi', value: '${_tree?.daysOld ?? 0} kun'),
          _InfoRow(icon: '💚', label: 'Salomatlik', value: _healthText(_tree?.currentHealth), valueColor: _healthColor(_tree?.currentHealth)),
          if (_tree?.healthTrend != null) _InfoRow(icon: _trendIcon(_tree?.healthTrend), label: 'Tendensiya', value: _tree?.healthTrend == 'improving' ? 'Yaxshilanmoqda' : _tree?.healthTrend == 'stable' ? 'Barqaror' : 'Yomonlashmoqda'),
          _InfoRow(icon: '💧', label: 'Sug\'orishlar', value: '${_tree?.totalWaterings ?? 0} marta'),
          _InfoRow(icon: '📷', label: 'Tekshiruvlar', value: '${_tree?.totalChecks ?? 0} marta'),
          _InfoRow(icon: '⭐', label: 'G\'amxo\'rlik', value: '${_tree?.careScore.toStringAsFixed(0) ?? 0}%'),
        ])).animate().fadeIn(delay: 100.ms),
        // AI Analysis
        if (_tree?.lastAiAnalysis != null) ...[
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Text('🤖', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('Greenify AI tahlili', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark))]),
            if (_tree?.lastAiAnalysis?.comment != null) ...[const SizedBox(height: 12), Text(_tree!.lastAiAnalysis!.comment!, style: const TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5))],
            if (_tree?.lastAiAnalysis?.detailedAnalysis != null) ...[
              if (_tree!.lastAiAnalysis!.detailedAnalysis!.positiveSigns.isNotEmpty) ...[const SizedBox(height: 12), const Text('✅ Ijobiy belgilar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.success)), const SizedBox(height: 6), ..._tree!.lastAiAnalysis!.detailedAnalysis!.positiveSigns.map((s) => Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Text('• $s', style: const TextStyle(fontSize: 13, color: AppColors.textMedium))))],
              if (_tree!.lastAiAnalysis!.detailedAnalysis!.problemsDetected.isNotEmpty) ...[const SizedBox(height: 12), const Text('⚠️ Muammolar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.warning)), const SizedBox(height: 6), ..._tree!.lastAiAnalysis!.detailedAnalysis!.problemsDetected.map((p) => Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Text('• $p', style: const TextStyle(fontSize: 13, color: AppColors.textMedium))))],
            ],
            if (_tree?.lastAiAnalysis?.recommendations != null && _tree!.lastAiAnalysis!.recommendations!.immediateActions.isNotEmpty) ...[const SizedBox(height: 12), const Text('📋 Tavsiyalar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(height: 6), ..._tree!.lastAiAnalysis!.recommendations!.immediateActions.map((a) => Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Text('• $a', style: const TextStyle(fontSize: 13, color: AppColors.textMedium))))],
          ])).animate().fadeIn(delay: 150.ms),
        ],
        // Active tasks
        if (_tree?.activeTasks.isNotEmpty ?? false) ...[
          const SizedBox(height: 20),
          const Text('📋 Aktiv vazifalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 12),
          ...(_tree!.activeTasks.map((t) => Container(
            margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.statusPending.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(TaskTypes.getIcon(t.type), style: const TextStyle(fontSize: 22)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(TaskTypes.getName(t.type), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                if (t.dueDateFormatted != null || t.timeRemaining != null) Text(t.timeRemaining ?? t.dueDateFormatted!, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.accentYellow.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('+${t.rewardPoints}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark))),
            ]),
          ))),
        ],
        // Health history
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('📊 Salomatlik tarixi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 12),
          ...(_history.take(5).map((h) => Container(
            margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppColors.cardShadow),
            child: Row(children: [
              if (h.photoUrl != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${api.baseUrl}${h.photoUrl}', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: AppColors.softGreen, child: const Icon(Icons.image, color: AppColors.textLight)))) else Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, color: AppColors.textLight)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.date.split('T').first, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                if (h.health != null) Text(_healthText(h.health), style: TextStyle(fontSize: 12, color: _healthColor(h.health))),
                if (h.aiComment != null) Text(h.aiComment!, style: const TextStyle(fontSize: 11, color: AppColors.textMedium), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ))),
        ],
        const SizedBox(height: 100),
      ])))),
    );
  }
  
  Widget _buildPlaceholder() => Container(color: AppColors.softGreen, child: Center(child: Text(TreePhases.getIcon(_tree?.phase ?? ''), style: const TextStyle(fontSize: 64))));
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip({required this.label, required this.color});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)));
}

class _InfoRow extends StatelessWidget {
  final String icon, label, value; final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Text(icon, style: const TextStyle(fontSize: 18)), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textMedium))), Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textDark))]));
}
