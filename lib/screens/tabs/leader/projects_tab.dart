import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';
import '/widgets/leader/projects_tab/filter_controls.dart';
import '/widgets/leader/projects_tab/project_card.dart';
import '/widgets/leader/projects_tab/create_project_dialog.dart';

class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  String? get userId => _supabase.auth.currentUser?.id;

  String _searchQuery = '';
  ProjectStatus? _selectedStatus;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();

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
            // Фильтры (как в WorksTab — без выбора проекта/этапа)
            FilterControls(
              searchQuery: _searchQuery,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              selectedStatus: _selectedStatus,
              onStatusChanged: (value) => setState(() => _selectedStatus = value),
            ),

            const SizedBox(height: 12),

            // Список проектов
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase
                    .from('projects')
                    .stream(primaryKey: ['id'])
                    .eq('created_by', userId!)
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Ошибка загрузки проектов',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    );
                  }

                  final projects = snapshot.data ?? [];

                  final filtered = projects.where((p) {
                    final nameMatch = (p['name'] as String)
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                    final statusMatch = _selectedStatus == null ||
                        p['status'] == _selectedStatus?.name;
                    return nameMatch && statusMatch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.folder_off,
                            size: 80,
                            color: colorScheme.primary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Нет проектов',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'По вашему запросу ничего не найдено'
                                : 'Нажмите "+" для создания первого проекта',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final project = filtered[index];

                      return AnimatedSlide(
                        duration: Duration(milliseconds: 300 + index * 50),
                        offset: Offset(0, index * 0.05),
                        curve: Curves.easeOutCubic,
                        child: ProjectCard(project: project),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // FAB — как в WorksTab: правый нижний угол, над таббаром
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: ScaleTransition(
          scale: _fabScaleAnimation,
          child: FloatingActionButton.extended(
            onPressed: () => CreateProjectDialog.show(context),
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 12,
            tooltip: 'Создать новый проект',
            label: const Text(
              'Новый проект',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            icon: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}