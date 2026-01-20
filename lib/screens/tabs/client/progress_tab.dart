import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeline_tile/timeline_tile.dart';
import '/models/enums.dart';

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (userId == null) return;

    try {
      // Только проекты, где роль = client
      final participantData = await _supabase
          .from('project_participants')
          .select('project_id, projects(id, name, description, start_date, end_date, status, manual_progress)')
          .eq('user_id', userId!)
          .eq('role', 'client');

      final myProjects = participantData
          .map((e) => e['projects'] as Map<String, dynamic>)
          .toList();

      setState(() {
        _projects = myProjects;
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  Future<double> _calculateOverallProgress(String projectId) async {
    try {
      // Сначала берём manual_progress (если заказчик его указал)
      final projectData = await _supabase
          .from('projects')
          .select('manual_progress')
          .eq('id', projectId)
          .maybeSingle();

      final manual = projectData?['manual_progress'] as num?;
      if (manual != null && manual > 0) {
        return (manual.toDouble() / 100).clamp(0.0, 1.0);
      }

      // Fallback — средний прогресс всех задач проекта
      final stagesData = await _supabase
          .from('stages')
          .select('id')
          .eq('project_id', projectId);

      if (stagesData.isEmpty) return 0.0;

      final stageIds = stagesData.map((s) => s['id'] as String).toList();

      final worksData = await _supabase
          .from('works')
          .select('progress')
          .inFilter('stage_id', stageIds);

      if (worksData.isEmpty) return 0.0;

      final totalProgress = worksData.fold<double>(0.0, (sum, w) => sum + (w['progress'] as num? ?? 0.0));
      return (totalProgress / worksData.length / 100).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Ошибка расчёта общего прогресса: $e');
      return 0.0;
    }
  }

  Future<double> _calculateStageProgress(String stageId) async {
    try {
      final worksData = await _supabase
          .from('works')
          .select('progress')
          .eq('stage_id', stageId);

      if (worksData.isEmpty) return 0.0;

      final totalProgress = worksData.fold<double>(0.0, (sum, w) => sum + (w['progress'] as num? ?? 0.0));
      return (totalProgress / worksData.length / 100).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Ошибка расчёта прогресса этапа: $e');
      return 0.0;
    }
  }

  Color _getStageStatusColor(StageStatus status) {
    return switch (status) {
      StageStatus.planned => Colors.grey,
      StageStatus.in_progress => Colors.blue,
      StageStatus.paused => Colors.orange,
      StageStatus.completed => Colors.green,
    };
  }

  String _stageStatusName(StageStatus status) {
    return switch (status) {
      StageStatus.planned => 'Запланирован',
      StageStatus.in_progress => 'В работе',
      StageStatus.paused => 'Приостановлен',
      StageStatus.completed => 'Завершён',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Выбор проекта (только где роль client)
          if (_projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButton<Map<String, dynamic>?>(
                isExpanded: true,
                hint: const Text('Выберите проект'),
                value: _selectedProject,
                items: _projects.map((project) {
                  return DropdownMenuItem(
                    value: project,
                    child: Text(project['name'] as String),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedProject = value),
              ),
            ),

          // Поиск
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                labelText: 'Поиск по названию этапа',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Основной контент
          Expanded(
            child: _selectedProject == null
                ? const Center(child: Text('Выберите проект для просмотра прогресса'))
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
                        final name = (s['name'] as String?)?.toLowerCase() ?? '';
                        return name.contains(_searchQuery);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('В проекте пока нет этапов'));
                      }

                      final now = DateTime.now();

                      return FutureBuilder<double>(
                        future: _calculateOverallProgress(_selectedProject!['id'] as String),
                        builder: (context, overallSnap) {
                          final overallProgress = overallSnap.data ?? 0.0;

                          return Column(
                            children: [
                              // Общий прогресс проекта
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Общий прогресс проекта',
                                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 16),
                                        LinearProgressIndicator(
                                          value: overallProgress,
                                          minHeight: 24,
                                          borderRadius: BorderRadius.circular(12),
                                          backgroundColor: Colors.grey[300],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            overallProgress >= 0.9
                                                ? Colors.green
                                                : overallProgress >= 0.6
                                                    ? Colors.blue
                                                    : Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '${(overallProgress * 100).toInt()}% завершено',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Timeline этапов
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final stage = filtered[index];
                                    final name = stage['name'] as String? ?? 'Без названия';
                                    final description = stage['description'] as String?;
                                    final statusStr = stage['status'] as String? ?? 'planned';
                                    final start = stage['start_date'] as String?;
                                    final end = stage['end_date'] as String?;

                                    final status = StageStatus.values.firstWhere(
                                      (e) => e.name == statusStr,
                                      orElse: () => StageStatus.planned,
                                    );

                                    final endDate = end != null ? DateTime.tryParse(end) : null;
                                    final isOverdue = endDate != null &&
                                        endDate.isBefore(now) &&
                                        status != StageStatus.completed;

                                    return FutureBuilder<double>(
                                      future: _calculateStageProgress(stage['id'] as String),
                                      builder: (context, stageProgressSnap) {
                                        final stageProgress = stageProgressSnap.data ?? 0.0;

                                        return TimelineTile(
                                          alignment: TimelineAlign.manual,
                                          lineXY: 0.1,
                                          isFirst: index == 0,
                                          isLast: index == filtered.length - 1,
                                          indicatorStyle: IndicatorStyle(
                                            width: 50,
                                            height: 50,
                                            indicatorXY: 0.5,
                                            drawGap: true,
                                            indicator: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _getStageStatusColor(status),
                                                border: Border.all(color: Colors.white, width: 3),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${(stageProgress * 100).toInt()}%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          beforeLineStyle: LineStyle(
                                            color: _getStageStatusColor(status).withOpacity(0.6),
                                            thickness: 6,
                                          ),
                                          afterLineStyle: LineStyle(
                                            color: _getStageStatusColor(status).withOpacity(0.6),
                                            thickness: 6,
                                          ),
                                          endChild: Card(
                                            margin: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            color: isOverdue ? Colors.red.shade50 : null,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.circle,
                                                        size: 14,
                                                        color: _getStageStatusColor(status),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          name,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 18,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (description != null && description.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(description, style: TextStyle(color: Colors.grey[700])),
                                                  ],
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${start ?? '?'} — ${end ?? '?'}',
                                                        style: TextStyle(color: Colors.grey[700]),
                                                      ),
                                                      if (isOverdue)
                                                        const Text(
                                                          'Просрочен!',
                                                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  LinearProgressIndicator(
                                                    value: stageProgress,
                                                    minHeight: 10,
                                                    borderRadius: BorderRadius.circular(5),
                                                    backgroundColor: Colors.grey[300],
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      stageProgress >= 0.9
                                                          ? Colors.green
                                                          : stageProgress >= 0.6
                                                              ? Colors.blue
                                                              : Colors.orange,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text(
                                                      '${(stageProgress * 100).toInt()}% завершено',
                                                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}