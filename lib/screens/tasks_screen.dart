import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'tree_detail_screen.dart';
import 'planting_wizard.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final appState = context.read<AppState>();
    await appState.loadUserTrees();
    await appState.loadUserTasks();
    await appState.loadNearbyTasks();
  }

  void _openPlantingWizard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PlantingWizard(),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPlantingWizard,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Yangi ko\'chat ekish'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vazifalar',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        Text(
                          'Daraxtlaringiz va vazifalar',
                          style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: const Center(child: Text('🌳', style: TextStyle(fontSize: 24))),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.cardShadow,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                labelColor: AppColors.primaryGreen,
                unselectedLabelColor: AppColors.textMedium,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '🌱 Mening daraxtlarim'),
                  Tab(text: '📋 Vazifalar'),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MyTreesTab(onRefresh: _loadData),
                  _NearbyTasksTab(onRefresh: _loadData),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MY TREES TAB ====================

class _MyTreesTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _MyTreesTab({required this.onRefresh});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d-MMMM, yyyy', 'uz_UZ').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.userTrees.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌱', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'Hali daraxt ekmadingiz',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Birinchi ko\'chatingizni eking!',
                  style: TextStyle(color: AppColors.textLight),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: appState.userTrees.length,
            itemBuilder: (context, index) {
              final tree = appState.userTrees[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TreeDetailScreen(treeId: tree.id),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.softGreen,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                TreePhases.getIcon(tree.phase),
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tree.name ?? 'Daraxt #${index + 1}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _StatusChip(
                                      label: TreePhases.getName(tree.phase),
                                      color: AppColors.primaryGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusChip(
                                      label: tree.status == 'active' ? 'Faol' : tree.status,
                                      color: tree.status == 'active'
                                          ? AppColors.success
                                          : tree.status == 'dead'
                                              ? AppColors.error
                                              : AppColors.statusRejected,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textLight),
                        ],
                      ),
                      if (tree.pendingTasksCount > 0 || tree.lastHealth != null) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (tree.pendingTasksCount > 0)
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.task_alt, size: 16, color: AppColors.statusPending),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${tree.pendingTasksCount} ta aktiv vazifa',
                                      style: const TextStyle(fontSize: 13, color: AppColors.statusPending, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            if (tree.lastHealth != null)
                              Row(
                                children: [
                                  const Icon(Icons.favorite, size: 16, color: AppColors.primaryGreen),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(tree.lastHealth! * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 13, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(tree.createdAt),
                            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)),
              );
            },
          ),
        );
      },
    );
  }
}

// ==================== NEARBY TASKS TAB ====================

class _NearbyTasksTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _NearbyTasksTab({required this.onRefresh});

  String _formatDueDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;

      if (diff == 0) return 'Bugun';
      if (diff == 1) return 'Ertaga';
      if (diff < 0) return 'Muddati o\'tgan';

      return DateFormat('d-MMMM').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case TaskStatus.pending:
        return AppColors.statusPending;
      case TaskStatus.claimed:
        return AppColors.statusClaimed;
      case TaskStatus.completed:
        return AppColors.statusCompleted;
      case TaskStatus.off:
        return AppColors.statusOff;
      case TaskStatus.rejected:
        return AppColors.statusRejected;
      default:
        return AppColors.textMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final tasks = appState.nearbyTasks.isNotEmpty ? appState.nearbyTasks : appState.userTasks;

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📋', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'Vazifalar topilmadi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Yaqin atrofda vazifalar yo\'q',
                  style: TextStyle(color: AppColors.textLight),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _TaskCard(
                task: task,
                onRefresh: onRefresh,
              ).animate().fadeIn(delay: Duration(milliseconds: 50 * index));
            },
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final Future<void> Function() onRefresh;

  const _TaskCard({required this.task, required this.onRefresh});

  Color _getStatusColor(String status) {
    switch (status) {
      case TaskStatus.pending:
        return AppColors.statusPending;
      case TaskStatus.claimed:
        return AppColors.statusClaimed;
      case TaskStatus.completed:
        return AppColors.statusCompleted;
      case TaskStatus.off:
        return AppColors.statusOff;
      case TaskStatus.rejected:
        return AppColors.statusRejected;
      default:
        return AppColors.textMedium;
    }
  }

  String _formatDueDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;

      if (diff == 0) return 'Bugun';
      if (diff == 1) return 'Ertaga';
      if (diff < 0) return 'Muddati o\'tgan';

      return DateFormat('d-MMMM').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _claimTask(BuildContext context) async {
    final result = await context.read<AppState>().claimTask(task.id);
    if (context.mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vazifa olindi! 30 daqiqa ichida bajaring.'), backgroundColor: AppColors.success),
        );
        onRefresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Xatolik'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(task.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: task.isClaimed ? statusColor.withOpacity(0.3) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    TaskTypes.getIcon(task.type),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            TaskTypes.getName(task.type),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                        ),
                        if (task.isMyTree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.softGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Mening daraxtim',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daraxt #${task.treeId}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Due date
              if (task.dueDate != null)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        'Muddati: ${_formatDueDate(task.dueDate)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                ),
              // Distance
              if (task.distanceMeters != null)
                Row(
                  children: [
                    const Icon(Icons.straighten, size: 16, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      '${task.distanceMeters!.toStringAsFixed(0)} m',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                  ],
                ),
              const SizedBox(width: 12),
              // Points
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '+${task.rewardPoints}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action button
          if (task.canBeClaimed)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _claimTask(context),
                child: const Text('Vazifani olish'),
              ),
            )
          else if (task.isClaimed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Open task execution flow
                },
                child: const Text('Bajarish'),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                task.isCompleted ? 'Bajarilgan ✓' : 'Band qilingan',
                textAlign: TextAlign.center,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
