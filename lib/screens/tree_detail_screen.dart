import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class TreeDetailScreen extends StatefulWidget {
  final String treeId;

  const TreeDetailScreen({super.key, required this.treeId});

  @override
  State<TreeDetailScreen> createState() => _TreeDetailScreenState();
}

class _TreeDetailScreenState extends State<TreeDetailScreen> {
  TreeModel? _tree;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await api.getTreeDetails(widget.treeId);

    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        _tree = result.data;
      } else {
        _error = result.error ?? 'Daraxt topilmadi';
      }
    });
  }

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_tree?.name ?? 'Daraxt #${widget.treeId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTree,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: AppColors.textMedium)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadTree, child: const Text('Qayta urinish')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTree,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tree Info Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.softGreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    TreePhases.getIcon(_tree!.phase),
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _tree!.name ?? 'Daraxt #${_tree!.id}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _InfoChip(
                                    label: TreePhases.getName(_tree!.phase),
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  _InfoChip(
                                    label: _tree!.status == 'active' ? 'Faol' : _tree!.status,
                                    color: _tree!.status == 'active' ? AppColors.success : AppColors.error,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _StatItem(icon: Icons.favorite, label: 'Sog\'lik', value: _tree!.lastHealth != null ? '${(_tree!.lastHealth! * 100).toStringAsFixed(0)}%' : '-'),
                                  _StatItem(icon: Icons.water_drop, label: 'Namlik', value: _tree!.lastSoilMoisture != null ? '${(_tree!.lastSoilMoisture! * 100).toStringAsFixed(0)}%' : '-'),
                                  _StatItem(icon: Icons.calendar_today, label: 'Ekilgan', value: _formatDate(_tree!.createdAt)),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(),

                        const SizedBox(height: 24),

                        // Pending Tasks
                        if (_tree!.pendingTasks.isNotEmpty) ...[
                          const Text(
                            '⏳ Kutilayotgan vazifalar',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_tree!.pendingTasks.length, (index) {
                            final task = _tree!.pendingTasks[index];
                            return _TaskCard(task: task, isPending: true)
                                .animate()
                                .fadeIn(delay: Duration(milliseconds: 50 * index));
                          }),
                          const SizedBox(height: 24),
                        ],

                        // Completed Tasks
                        if (_tree!.completedTasks.isNotEmpty) ...[
                          const Text(
                            '✅ Bajarilgan vazifalar',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_tree!.completedTasks.take(10).length, (index) {
                            final task = _tree!.completedTasks[index];
                            return _TaskCard(task: task, isPending: false)
                                .animate()
                                .fadeIn(delay: Duration(milliseconds: 50 * index));
                          }),
                        ],

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.primaryGreen),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isPending;

  const _TaskCard({required this.task, required this.isPending});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: isPending ? AppColors.statusPending.withOpacity(0.3) : AppColors.statusCompleted.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPending ? AppColors.statusPending.withOpacity(0.1) : AppColors.statusCompleted.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(TaskTypes.getIcon(task.type), style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TaskTypes.getName(task.type),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                if (task.dueDate != null)
                  Text(
                    'Muddati: ${task.dueDate}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${task.rewardPoints} ⭐',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Bajarish',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
