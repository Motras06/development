// stages_tab.dart
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

  List<Map<String, dynamic>> _stages = [];
  bool _isLoadingStages = false;
  String? _stagesError;

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
    try {
      final participantData = await _supabase
          .from('project_participants')
          .select('project_id, projects(id, name)')
          .eq('user_id', userId!);

      final myProjects = participantData.map((e) => e['projects'] as Map<String, dynamic>).toList();

      setState(() {
        _projects = myProjects;
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
          _loadStages();
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  Future<void> _loadStages() async {
    if (_selectedProject == null) return;

    setState(() {
      _isLoadingStages = true;
      _stagesError = null;
    });

    try {
      final data = await _supabase
          .from('stages')
          .select()
          .eq('project_id', _selectedProject!['id'])
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _stages = List<Map<String, dynamic>>.from(data);
          _isLoadingStages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stagesError = e.toString();
          _isLoadingStages = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStages {
    return _stages.where((s) {
      return (s['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorScheme.primary.withOpacity(0.05), colorScheme.surface],
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ProjectDropdown(
                  projects: _projects,
                  selectedProject: _selectedProject,
                  onChanged: (value) {
                    setState(() => _selectedProject = value);
                    if (value != null) _loadStages();
                  },
                ),
              ),

              FilterControls(
                searchQuery: _searchQuery,
                onSearchChanged: (value) => setState(() => _searchQuery = value),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: _selectedProject == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.view_week_outlined,
                                size: 80, color: colorScheme.primary.withOpacity(0.4)),
                            const SizedBox(height: 16),
                            Text('Выберите проект',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                            const SizedBox(height: 8),
                            Text('Чтобы увидеть этапы',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.5))),
                          ],
                        ),
                      )
                    : _isLoadingStages
                        ? const Center(child: CircularProgressIndicator())
                        : _stagesError != null
                            ? Center(child: Text('Ошибка: $_stagesError'))
                            : _filteredStages.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.view_week,
                                            size: 80, color: colorScheme.primary.withOpacity(0.4)),
                                        const SizedBox(height: 16),
                                        Text('Нет этапов',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                                        const SizedBox(height: 8),
                                        Text('Нажмите "+" для создания первого этапа',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(color: colorScheme.onSurface.withOpacity(0.5))),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadStages,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      itemCount: _filteredStages.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        return AnimatedSlide(
                                          duration: Duration(milliseconds: 300 + index * 50),
                                          offset: Offset(0, index * 0.05),
                                          curve: Curves.easeOutCubic,
                                          child: StageCard(
                                            stage: _filteredStages[index],
                                            onRefresh: _loadStages, // ← теперь работает
                                          ),
                                        );
                                      },
                                    ),
                                  ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: ScaleTransition(
          scale: _fabScaleAnimation,
          child: FloatingActionButton.extended(
            onPressed: _selectedProject == null
                ? null
                : () => CreateStageDialog.show(
                      context,
                      projectId: _selectedProject!['id'],
                      onSuccess: _loadStages,
                    ),
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