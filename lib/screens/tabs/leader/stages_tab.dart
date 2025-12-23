import 'package:development/widgets/leader/stages_tab/create_stage_dialog.dart';
import 'package:development/widgets/leader/stages_tab/stage_card.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/leader/stages_tab/filter_controls.dart';
import '../../../widgets/leader/stages_tab/project_dropdown.dart';

class StagesTab extends StatefulWidget {
  const StagesTab({super.key});

  @override
  State<StagesTab> createState() => _StagesTabState();
}

class _StagesTabState extends State<StagesTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  String? get userId => _supabase.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  String _searchQuery = '';

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadProjects();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    if (userId == null) return;

    try {
      final data = await _supabase
          .from('projects')
          .select('id, name')
          .eq('created_by', userId!)
          .order('created_at', ascending: false);

      setState(() {
        _projects = List<Map<String, dynamic>>.from(data);
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.05),
              colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            // Выбор проекта — теперь с красивым ProjectDropdown
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ProjectDropdown(
                projects: _projects,
                selectedProject: _selectedProject,
                onChanged: (value) => setState(() => _selectedProject = value),
              ),
            ),

            // Поиск
            FilterControls(
              searchQuery: _searchQuery,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
            ),

            const SizedBox(height: 12),

            // Список этапов
            Expanded(
              child: _selectedProject == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.view_week_outlined, size: 80, color: colorScheme.primary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text('Выберите проект', style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                          const SizedBox(height: 8),
                          Text('Чтобы увидеть этапы', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    )
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _supabase
                          .from('stages')
                          .stream(primaryKey: ['id'])
                          .eq('project_id', _selectedProject!['id'])
                          .order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Ошибка: ${snapshot.error}'));
                        }

                        final stages = snapshot.data ?? [];

                        final filtered = stages.where((s) {
                          return (s['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.view_week, size: 80, color: colorScheme.primary.withOpacity(0.4)),
                                const SizedBox(height: 16),
                                Text('Нет этапов', style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                                const SizedBox(height: 8),
                                Text('Нажмите "+" для создания первого этапа', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.5))),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return AnimatedSlide(
                              duration: Duration(milliseconds: 300 + index * 50),
                              offset: Offset(0, index * 0.05),
                              curve: Curves.easeOutCubic,
                              child: StageCard(stage: filtered[index]),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // FAB
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: ScaleTransition(
          scale: _fabScaleAnimation,
          child: FloatingActionButton.extended(
            onPressed: _selectedProject == null
                ? null
                : () => CreateStageDialog.show(context, projectId: _selectedProject!['id']),
            backgroundColor: _selectedProject == null
                ? colorScheme.surface.withOpacity(0.6)
                : colorScheme.primary,
            foregroundColor: _selectedProject == null
                ? colorScheme.onSurface.withOpacity(0.4)
                : Colors.white,
            elevation: 12,
            label: const Text('Новый этап', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            icon: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}