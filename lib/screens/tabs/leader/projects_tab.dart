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

  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  String? _error;

  String _searchQuery = '';
  ProjectStatus? _selectedStatus;

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
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('projects')
          .select()
          .eq('created_by', userId!)
          .order('created_at', ascending: false)
          .limit(200);

      if (mounted) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProjects {
    return _projects.where((p) {
      final nameMatch = (p['name'] as String?)
              ?.toLowerCase()
              .contains(_searchQuery.toLowerCase()) ??
          false;
      final statusMatch =
          _selectedStatus == null || p['status'] == _selectedStatus?.name;
      return nameMatch && statusMatch;
    }).toList();
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
            FilterControls(
              searchQuery: _searchQuery,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              selectedStatus: _selectedStatus,
              onStatusChanged: (value) => setState(() => _selectedStatus = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            'Ошибка: $_error',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        )
                      : _filteredProjects.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                            )
                          : RefreshIndicator(
                              onRefresh: _loadProjects,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: _filteredProjects.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final project = _filteredProjects[index];
                                  return AnimatedSlide(
                                    duration:
                                        Duration(milliseconds: 300 + index * 50),
                                    offset: Offset(0, index * 0.05),
                                    curve: Curves.easeOutCubic,
                                    child: ProjectCard(
                                      project: project,
                                      onRefresh: _loadProjects,
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: ScaleTransition(
          scale: _fabScaleAnimation,
          child: FloatingActionButton.extended(
            onPressed: () => CreateProjectDialog.show(
              context,
              onSuccess: _loadProjects,
            ),
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