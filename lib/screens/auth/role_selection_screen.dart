import 'package:development/screens/settings/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppRole { leader, worker, client }

class RoleItem {
  final AppRole role;
  final String title;
  final String value;
  final IconData icon;
  final String description;

  const RoleItem({
    required this.role,
    required this.title,
    required this.value,
    required this.icon,
    required this.description,
  });
}

final List<RoleItem> _roleItems = [
  const RoleItem(
    role: AppRole.leader,
    title: 'Руководитель',
    value: 'leader',
    icon: Icons.engineering,
    description: 'Создаю проекты, управляю этапами и командой',
  ),
  const RoleItem(
    role: AppRole.worker,
    title: 'Работник',
    value: 'worker',
    icon: Icons.build,
    description: 'Выполняю задачи, отчитываюсь о прогрессе',
  ),
  const RoleItem(
    role: AppRole.client,
    title: 'Заказчик',
    value: 'client',
    icon: Icons.home_work,
    description: 'Отслеживаю прогресс строительства',
  ),
];

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  AppRole? _selectedRole;

  late AnimationController _controller;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _cardAnimations = List.generate(_roleItems.length, (index) {
      final delay = 0.15 + (index * 0.15);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectRole(AppRole role) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRole = role;
    });
  }

  void _confirm() {
    if (_selectedRole == null) {
      HapticFeedback.lightImpact();
      return;
    }

    HapticFeedback.heavyImpact();

    final selectedItem = _roleItems.firstWhere((item) => item.role == _selectedRole);
    Navigator.of(context).pop(selectedItem.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.2),
              AppColors.accentLight.withOpacity(0.5),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),

                FadeTransition(
                  opacity: _controller.drive(Tween(begin: 0.0, end: 1.0)),
                  child: Column(
                    children: [
                      Text(
                        'СтройТрек',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 48,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Кем вы будете в проекте?',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _roleItems.length,
                    itemBuilder: (context, index) {
                      final item = _roleItems[index];
                      final isSelected = _selectedRole == item.role;

                      return AnimatedBuilder(
                        animation: _cardAnimations[index],
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 80 * (1 - _cardAnimations[index].value)),
                            child: Opacity(
                              opacity: _cardAnimations[index].value,
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: GestureDetector(
                            onTap: () => _selectRole(item.role),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutExpo,
                              height: 180,
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.primary : colorScheme.surface,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(isSelected ? 0.5 : 0.15),
                                    blurRadius: isSelected ? 40 : 20,
                                    offset: Offset(0, isSelected ? 20 : 10),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 60,
                                      color: isSelected ? Colors.white : colorScheme.primary,
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item.description,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: isSelected ? Colors.white70 : colorScheme.onSurface.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle, size: 40, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _selectedRole == null ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: _selectedRole == null ? 0 : 12,
                      shadowColor: colorScheme.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    ),
                    child: Text(
                      _selectedRole == null ? 'Выберите роль' : 'Продолжить',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}