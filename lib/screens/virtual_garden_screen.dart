import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_colors.dart';

class PlantType {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final String care;
  final String water;
  final String light;
  final int level;
  final bool unlocked;

  PlantType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.care,
    required this.water,
    required this.light,
    this.level = 1,
    this.unlocked = true,
  });
}

class VirtualGardenScreen extends StatefulWidget {
  const VirtualGardenScreen({super.key});
  @override
  State<VirtualGardenScreen> createState() => _VirtualGardenScreenState();
}

class _VirtualGardenScreenState extends State<VirtualGardenScreen> {
  final List<PlantType> plants = [
    PlantType(
      id: '1',
      name: 'Kaktus kolleksiyasi',
      emoji: '🌵',
      category: 'Kaktuslar',
      care: 'Oson',
      water: 'Oyiga 1-2 marta',
      light: 'To\'g\'ridan-to\'g\'ri quyosh',
    ),
    PlantType(
      id: '2',
      name: 'Fikus',
      emoji: '🌿',
      category: 'Uy gullari',
      care: 'O\'rtacha',
      water: 'Haftasiga 1 marta',
      light: 'Yorqin, bilvosita',
    ),
    PlantType(
      id: '3',
      name: 'Monstera',
      emoji: '🍃',
      category: 'Uy gullari',
      care: 'Oson',
      water: 'Haftasiga 1 marta',
      light: 'O\'rtacha yorug\'lik',
    ),
    PlantType(
      id: '4',
      name: 'Rayhon',
      emoji: '🌱',
      category: 'Ziravorlar',
      care: 'O\'rtacha',
      water: 'Kuniga 1 marta',
      light: 'Yorqin quyosh',
    ),
    PlantType(
      id: '5',
      name: 'Yalpiz',
      emoji: '🌿',
      category: 'Ziravorlar',
      care: 'Oson',
      water: 'Kuniga 1 marta',
      light: 'Quyosh yoki soya',
    ),
    PlantType(
      id: '6',
      name: 'Bonsai',
      emoji: '🌳',
      category: 'Mini daraxtlar',
      care: 'Qiyin',
      water: '2 kunda 1 marta',
      light: 'Yorqin yorug\'lik',
      level: 2,
    ),
    PlantType(
      id: '7',
      name: 'Orkideya',
      emoji: '🌸',
      category: 'Gullaydigan',
      care: 'O\'rtacha',
      water: 'Haftasiga 1 marta',
      light: 'Yorqin, bilvosita',
    ),
    PlantType(
      id: '8',
      name: 'Begoniya',
      emoji: '🌺',
      category: 'Gullaydigan',
      care: 'Oson',
      water: 'Haftasiga 2 marta',
      light: 'Yorqin yorug\'lik',
    ),
    PlantType(
      id: '9',
      name: 'Aloe Vera',
      emoji: '🪴',
      category: 'Tibbiy o\'simliklar',
      care: 'Juda oson',
      water: 'Oyiga 2 marta',
      light: 'Yorqin quyosh',
    ),
  ];

  String _selectedCategory = 'Hammasi';

  List<String> get categories {
    final cats = plants.map((p) => p.category).toSet().toList();
    return ['Hammasi', ...cats];
  }

  List<PlantType> get filteredPlants {
    if (_selectedCategory == 'Hammasi') return plants;
    return plants.where((p) => p.category == _selectedCategory).toList();
  }

  Color _getCareColor(String care) {
    switch (care.toLowerCase()) {
      case 'juda oson':
      case 'oson':
        return AppColors.success;
      case 'o\'rtacha':
        return AppColors.warning;
      case 'qiyin':
        return AppColors.error;
      default:
        return AppColors.textMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Virtual Bog\'',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'O\'simliklar kolleksiyasi',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMedium,
                              ),
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
                        child: const Center(
                          child: Text('🌿', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryGreen : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected ? AppColors.cardShadow : null,
                              border: Border.all(
                                color: isSelected ? AppColors.primaryGreen : AppColors.textLight.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.textMedium,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filteredPlants.length,
                itemBuilder: (context, index) {
                  final plant = filteredPlants[index];
                  return GestureDetector(
                    onTap: () => _showPlantDetail(plant),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            plant.emoji,
                            style: const TextStyle(fontSize: 64),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              plant.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCareColor(plant.care).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              plant.care,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getCareColor(plant.care),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lvl ${plant.level}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ).animate().scale(delay: Duration(milliseconds: 50 * index)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlantDetail(PlantType plant) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(plant.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              plant.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                plant.category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _InfoRow(
                    icon: '💧',
                    label: 'Sug\'orish',
                    value: plant.water,
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: '☀️',
                    label: 'Yorug\'lik',
                    value: plant.light,
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: '🛡️',
                    label: 'Parvarish',
                    value: plant.care,
                    valueColor: _getCareColor(plant.care),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: '📊',
                    label: 'Daraja',
                    value: 'Level ${plant.level}',
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Yopish'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}