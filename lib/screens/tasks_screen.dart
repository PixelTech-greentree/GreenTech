import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../services/app_state.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daraxtlarim va vazifalar',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${appState.userTrees.length} ta daraxt parvarish qilish kerak',
                            style: const TextStyle(fontSize: 14, color: AppColors.textMedium),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.filter_list, size: 18, color: AppColors.primaryGreen),
                            SizedBox(width: 6),
                            Text('Filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryGreen)),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                ),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: appState.userTrees.length,
                    itemBuilder: (context, index) {
                      final tree = appState.userTrees[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.softGreen,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(child: Text('🌳', style: TextStyle(fontSize: 28))),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(tree.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLight),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                tree.location,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: tree.progress == 1 ? AppColors.softGreen : AppColors.cardBackground,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${tree.completedTasks}/${tree.totalTasks}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: tree.progress == 1 ? AppColors.primaryGreen : AppColors.textMedium,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: tree.progress,
                                  backgroundColor: AppColors.cardBackground,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    tree.progress == 1 ? AppColors.success : AppColors.primaryGreen,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...tree.tasks.map((task) => GestureDetector(
                              onTap: () => appState.toggleTask(tree.id, task.id),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: task.isCompleted ? AppColors.primaryGreen : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: task.isCompleted ? AppColors.primaryGreen : AppColors.textLight.withOpacity(0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: task.isCompleted ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        task.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: task.isCompleted ? AppColors.textLight : AppColors.textDark,
                                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    if (!task.isCompleted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Bugun',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            )),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: 100 * index));
                    },
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 22),
                      label: const Text('Yangi daraxt qo\'shish'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
