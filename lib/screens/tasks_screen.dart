import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'tree_detail_screen.dart';
import 'planting_wizard.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); WidgetsBinding.instance.addPostFrameCallback((_) => _loadData()); }
  @override void dispose() { _tabController.dispose(); super.dispose(); }
  Future<void> _loadData() async { final a = context.read<AppState>(); await a.loadUserTrees(); await a.loadNearbyTasks(); }
  void _openPlantingWizard() { Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PlantingWizard())).then((_) => _loadData()); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(onPressed: _openPlantingWizard, backgroundColor: AppColors.primaryGreen, icon: const Icon(Icons.add), label: const Text('Yangi ko\'chat')),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Vazifalar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)), Text('Daraxtlaringiz va vazifalar', style: TextStyle(fontSize: 14, color: AppColors.textMedium))])),
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppColors.cardShadow), child: const Center(child: Text('🌳', style: TextStyle(fontSize: 24)))),
        ])).animate().fadeIn(duration: 400.ms),
        Container(margin: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)), child: TabBar(
          controller: _tabController, indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppColors.cardShadow),
          indicatorSize: TabBarIndicatorSize.tab, indicatorPadding: const EdgeInsets.all(4), labelColor: AppColors.primaryGreen, unselectedLabelColor: AppColors.textMedium,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), dividerColor: Colors.transparent, tabs: const [Tab(text: '🌱 Daraxtlarim'), Tab(text: '📋 Vazifalar')],
        )).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 16),
        Expanded(child: TabBarView(controller: _tabController, children: [_MyTreesTab(onRefresh: _loadData), _NearbyTasksTab(onRefresh: _loadData)])),
      ])),
    );
  }
}

class _MyTreesTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _MyTreesTab({required this.onRefresh});
  @override Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, child) {
      if (appState.userTrees.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🌱', style: TextStyle(fontSize: 64)), SizedBox(height: 16), Text('Hali daraxt ekmadingiz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMedium)), SizedBox(height: 100)]));
      return RefreshIndicator(onRefresh: onRefresh, child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: appState.userTrees.length, itemBuilder: (ctx, i) => _TreeCard(tree: appState.userTrees[i], index: i).animate().fadeIn(delay: Duration(milliseconds: 50 * i))));
    });
  }
}

class _TreeCard extends StatelessWidget {
  final TreeModel tree;
  final int index;
  
  const _TreeCard({required this.tree, required this.index});
  
  Color _healthColor(String? h) {
    switch (h) {
      case 'healthy': return AppColors.success;
      case 'stressed': return AppColors.warning;
      case 'critical': return AppColors.error;
      default: return AppColors.textMedium;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TreeDetailScreen(treeId: tree.id))
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Tree image
                Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: tree.latestPhotoUrl != null
                        ? Image.network(
                            '${api.baseUrl}${tree.latestPhotoUrl}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                TreePhases.getIcon(tree.phase),
                                style: const TextStyle(fontSize: 40),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              TreePhases.getIcon(tree.phase),
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                  ),
                ),
                
                // Tree info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          tree.name ?? 'Daraxt #${index + 1}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 6),
                        
                        // Phase & Status chips
                        Row(
                          children: [
                            _MiniChip(
                              label: TreePhases.getName(tree.phase),
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            _MiniChip(
                              label: tree.status == 'active' ? 'Faol' : tree.status,
                              color: tree.status == 'active' 
                                  ? AppColors.success 
                                  : AppColors.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Date & Health - ✅ TUZATILDI
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 4),
                            Expanded( // ✅ QO'SHILDI
                              child: Text(
                                tree.plantedDateFormatted ?? '${tree.daysOld} kun',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (tree.currentHealth != null) ...[
                              const SizedBox(width: 8), // ✅ 12 → 8
                              Icon(
                                Icons.favorite,
                                size: 12,
                                color: _healthColor(tree.currentHealth),
                              ),
                              const SizedBox(width: 2), // ✅ 4 → 2
                              Text(
                                tree.currentHealth == 'healthy' 
                                    ? 'Sog\'lom' 
                                    : tree.currentHealth!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _healthColor(tree.currentHealth),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Arrow icon
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right, color: AppColors.textLight),
                ),
              ],
            ),
            
            // Tasks footer
            if (tree.activeTasks.isNotEmpty || tree.pendingTasksCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.statusPending.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.task_alt,
                      size: 18,
                      color: AppColors.statusPending,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tree.activeTasks.isNotEmpty ? tree.activeTasks.length : tree.pendingTasksCount} ta vazifa',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.statusPending,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label; final Color color;
  const _MiniChip({required this.label, required this.color});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)));
}

class _NearbyTasksTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _NearbyTasksTab({required this.onRefresh});
  @override Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, child) {
      if (appState.nearbyTasks.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('📋', style: TextStyle(fontSize: 64)), SizedBox(height: 16), Text('Vazifalar topilmadi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMedium)), SizedBox(height: 100)]));
      return RefreshIndicator(onRefresh: onRefresh, child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: appState.nearbyTasks.length, itemBuilder: (ctx, i) => _NearbyTaskCard(task: appState.nearbyTasks[i], onRefresh: onRefresh).animate().fadeIn(delay: Duration(milliseconds: 50 * i))));
    });
  }
}

class _NearbyTaskCard extends StatefulWidget {
  final TaskModel task; final Future<void> Function() onRefresh;
  const _NearbyTaskCard({required this.task, required this.onRefresh});
  @override State<_NearbyTaskCard> createState() => _NearbyTaskCardState();
}

class _NearbyTaskCardState extends State<_NearbyTaskCard> {
  bool _isLoading = false;

  Future<void> _claimTask() async {
    setState(() => _isLoading = true);
    final result = await context.read<AppState>().claimTask(widget.task.id);
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.success ? result.data!.message : result.error ?? 'Xatolik'), backgroundColor: result.success ? AppColors.success : AppColors.error));
    if (result.success) widget.onRefresh();
  }

  void _completeTask() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => _TaskCompletionSheet(task: widget.task, onComplete: () { Navigator.pop(ctx); widget.onRefresh(); }));
  }

  @override Widget build(BuildContext context) {
    final t = widget.task;
    final statusColor = t.isClaimed ? AppColors.statusClaimed : t.isCompleted ? AppColors.statusCompleted : AppColors.statusPending;
    return Container(
      margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow, border: t.isClaimed ? Border.all(color: statusColor.withOpacity(0.4), width: 2) : null),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(TaskTypes.getIcon(t.type), style: const TextStyle(fontSize: 26)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(TaskTypes.getName(t.type), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark))), if (t.isOwnTree) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Text('Mening', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primaryGreen)))]),
            if (t.treeOwnerName != null && !t.isOwnTree) Text('${t.treeOwnerName}', style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          if (t.timeRemaining != null) Expanded(child: Row(children: [Icon(Icons.schedule, size: 14, color: t.isUrgent ? AppColors.error : AppColors.textLight), const SizedBox(width: 4), Text(t.timeRemaining!, style: TextStyle(fontSize: 12, color: t.isUrgent ? AppColors.error : AppColors.textMedium, fontWeight: t.isUrgent ? FontWeight.w600 : FontWeight.normal))])),
          if (t.distanceFormatted != null) Row(children: [const Icon(Icons.place, size: 14, color: AppColors.textLight), const SizedBox(width: 4), Text(t.distanceFormatted!, style: const TextStyle(fontSize: 12, color: AppColors.textMedium))]),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.accentYellow.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('⭐', style: TextStyle(fontSize: 12)), const SizedBox(width: 4), Text('+${t.rewardPoints}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark))])),
        ]),
        if (t.description != null) ...[const SizedBox(height: 12), Text(t.description!, style: const TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)],
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: _isLoading ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : t.canBeClaimed ? OutlinedButton.icon(onPressed: _claimTask, icon: const Icon(Icons.add_task, size: 18), label: const Text('Vazifani olish')) : t.isClaimed ? ElevatedButton.icon(onPressed: _completeTask, icon: const Icon(Icons.camera_alt, size: 18), label: const Text('Rasmga olib bajarish')) : Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(t.isCompleted ? 'Bajarilgan ✓' : 'Band qilingan', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600))))),
      ])),
    );
  }
}

class _TaskCompletionSheet extends StatefulWidget {
  final TaskModel task; final VoidCallback onComplete;
  const _TaskCompletionSheet({required this.task, required this.onComplete});
  @override State<_TaskCompletionSheet> createState() => _TaskCompletionSheetState();
}

class _TaskCompletionSheetState extends State<_TaskCompletionSheet> {
  bool _isLoading = false; String? _error; TaskCompletionResponse? _response;

  Future<void> _takePhotoAndComplete() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
      if (photo == null) { setState(() => _isLoading = false); return; }
      Position position;
      try { position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high); } catch (e) { setState(() { _isLoading = false; _error = 'Joylashuvni aniqlab bo\'lmadi'; }); return; }
      final result = await api.completeTask(taskId: widget.task.id, latitude: position.latitude, longitude: position.longitude, imageFile: File(photo.path));
      if (!mounted) return;
      if (result.success && result.data != null) { setState(() { _isLoading = false; _response = result.data; }); } else { setState(() { _isLoading = false; _error = result.error ?? 'Xatolik yuz berdi'; }); }
    } catch (e) { setState(() { _isLoading = false; _error = 'Xatolik: $e'; }); }
  }

  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: _response != null ? _buildSuccess() : _buildCapture());
  }

  Widget _buildCapture() => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textLight.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
    const SizedBox(height: 24), Text(TaskTypes.getIcon(widget.task.type), style: const TextStyle(fontSize: 56)),
    const SizedBox(height: 16), Text(TaskTypes.getName(widget.task.type), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
    const SizedBox(height: 8), Text(widget.task.description ?? 'Vazifani bajarib rasmga oling', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textMedium)),
    if (_error != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color: AppColors.error, size: 20), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error)))]))],
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: _isLoading ? null : _takePhotoAndComplete, icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt, size: 24), label: Text(_isLoading ? 'Yuborilmoqda...' : 'Rasmga olish'))),
    const SizedBox(height: 16),
  ]);

  Widget _buildSuccess() {
    final r = _response!; final f = r.aiFeedback;
    return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(r.success ? '🎉' : '⚠️', style: const TextStyle(fontSize: 64)),
      const SizedBox(height: 16), Text(r.success ? 'Muvaffaqiyatli!' : 'Diqqat!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: r.success ? AppColors.primaryGreen : AppColors.warning)),
      const SizedBox(height: 8), Text(r.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.textMedium)),
      if (r.pointsEarned > 0) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(gradient: AppColors.cardGradient, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('⭐', style: TextStyle(fontSize: 24)), const SizedBox(width: 8), Text('+${r.pointsEarned} ball', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))]))],
      if (f != null && f.comment != null) ...[const SizedBox(height: 20), Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Text('🤖', style: TextStyle(fontSize: 18)), SizedBox(width: 8), Text('Greenify AI', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark))]),
        const SizedBox(height: 8), Text(f.comment!, style: const TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5)),
        if (f.recommendations != null && f.recommendations!.immediateActions.isNotEmpty) ...[const SizedBox(height: 12), const Text('📋 Tavsiyalar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(height: 6), ...f.recommendations!.immediateActions.map((a) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• ', style: TextStyle(color: AppColors.primaryGreen)), Expanded(child: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)))])))],
      ]))],
      const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: widget.onComplete, child: const Text('Tayyor'))),
    ]));
  }
}
class TasksScreenContent extends StatelessWidget {
  const TasksScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(  // ✅ const olib tashlandi
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [  // ✅ Faqat bu yerda const qoldi
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: AppColors.textMedium,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '🌱 Daraxtlarim'),
                    Tab(text: '📋 Vazifalar'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _MyTreesTab(onRefresh: () => appState.loadUserTrees()),
                    _NearbyTasksTab(onRefresh: () => appState.loadNearbyTasks()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}