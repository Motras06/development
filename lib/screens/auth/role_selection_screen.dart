import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppRole { leader, worker, client }

class RoleItem {
  final AppRole role;
  final String title;
  final String value; // добавили value для возврата
  final IconData icon;
  final String description;

  const RoleItem(this.role, this.title, this.value, this.icon, this.description);
}

final List<RoleItem> _roleItems = [
  const RoleItem(
    AppRole.leader,
    'Руководитель',
    'leader',
    Icons.engineering,
    'Создаю проекты, управляю этапами и командой',
  ),
  const RoleItem(
    AppRole.worker,
    'Работник',
    'worker',
    Icons.build,
    'Выполняю задачи, отчитываюсь о прогрессе',
  ),
  const RoleItem(
    AppRole.client,
    'Заказчик',
    'client',
    Icons.home_work,
    'Отслеживаю прогресс строительства',
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
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectRole(AppRole role) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedRole = role;
    });
  }

  void _confirm() {
    if (_selectedRole == null) return;

    HapticFeedback.mediumImpact();

    // Находим выбранный item и возвращаем его value
    final selectedItem = _roleItems.firstWhere((item) => item.role == _selectedRole);
    
    Navigator.of(context).pop(selectedItem.value); // ← возвращаем 'leader' / 'worker' / 'client'
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.blue[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Выбор роли'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  elevation: 16.0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'СтройТрек',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Кем вы будете работать?',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          alignment: WrapAlignment.center,
                          children: _roleItems.map((item) {
                            final isSelected = _selectedRole == item.role;

                            return GestureDetector(
                              onTap: () => _selectRole(item.role),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surface.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                                    width: isSelected ? 3 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: theme.colorScheme.primary.withOpacity(0.4),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 40,
                                      color: isSelected ? Colors.white : theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      item.title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected ? Colors.white70 : theme.textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 40),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedRole == null ? null : _confirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 6,
                            ),
                            child: Text(
                              _selectedRole == null ? 'Выберите роль' : 'Продолжить',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}