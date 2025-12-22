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
      final participantData = await _supabase
          .from('project_participants')
          .select('project_id, projects(name, description, start_date, end_date)')
          .eq('user_id', userId!)
          .eq('role', ParticipantRole.client.name);

      final projectIds = participantData.map((p) => p['project_id'] as String).toList();

      if (projectIds.isEmpty) {
        setState(() => _projects = []);
        return;
      }

      final projectsData = await _supabase
          .from('projects')
          .select('id, name, description, start_date, end_date, status')
          .inFilter('id', projectIds)
          .order('created_at', ascending: false);

      setState(() {
        _projects = List<Map<String, dynamic>>.from(projectsData);
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
    return Scaffold(
      body: Column(
        children: [
          // Выбор проекта
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
                    child: Text(project['name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedProject = value),
              ),
            ),

          // Поиск по этапам
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                labelText: 'Поиск по названию этапа',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Дашборд прогресса
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

                      if (stages.isEmpty) {
                        return const Center(child: Text('В проекте пока нет этапов'));
                      }

                      final now = DateTime.now();

                      // Фильтрация
                      final filteredStages = stages.where((stage) {
                        return (stage['name'] as String)
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                      }).toList();

                      // Общий прогресс проекта
                      return FutureBuilder<double>(
                        future: _calculateOverallProgress(_selectedProject!['id']),
                        builder: (context, progressSnapshot) {
                          final overallProgress = progressSnapshot.data ?? 0.0;

                          return Column(
                            children: [
                              // Общий прогресс
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Общий прогресс проекта',
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 16),
                                        LinearProgressIndicator(
                                          value: overallProgress,
                                          minHeight: 20,
                                          backgroundColor: Colors.grey[300],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            overallProgress >= 1.0
                                                ? Colors.green
                                                : overallProgress >= 0.7
                                                    ? Colors.blue
                                                    : Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${(overallProgress * 100).toInt()}% завершено',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Timeline этапов
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filteredStages.length,
                                  itemBuilder: (context, index) {
                                    final stage = filteredStages[index];
                                    final name = stage['name'] as String;
                                    final description = stage['description'] as String?;
                                    final statusStr = stage['status'] as String;
                                    final startStr = stage['start_date'] as String?;
                                    final endStr = stage['end_date'] as String?;

                                    final status = StageStatus.values.firstWhere(
                                      (e) => e.name == statusStr,
                                      orElse: () => StageStatus.planned,
                                    );

                                    final start = startStr != null ? DateTime.tryParse(startStr) : null;
                                    final end = endStr != null ? DateTime.tryParse(endStr) : null;
                                    final isOverdue = end != null && end.isBefore(now) && status != StageStatus.completed;

                                    // Прогресс этапа
                                    return FutureBuilder<double>(
                                      future: _calculateStageProgress(stage['id']),
                                      builder: (context, stageProgressSnap) {
                                        final stageProgress = stageProgressSnap.data ?? 0.0;

                                        return TimelineTile(
                                          alignment: TimelineAlign.manual,
                                          lineXY: 0.1,
                                          isFirst: index == 0,
                                          isLast: index == filteredStages.length - 1,
                                          indicatorStyle: IndicatorStyle(
                                            width: 40,
                                            height: 40,
                                            indicator: Container(
                                              decoration: BoxDecoration(
                                                color: _getStageStatusColor(status),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${(stageProgress * 100).toInt()}%',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ),
                                          beforeLineStyle: LineStyle(
                                            color: _getStageStatusColor(status),
                                            thickness: 6,
                                          ),
                                          endChild: Card(
                                            margin: const EdgeInsets.all(8),
                                            color: isOverdue ? Colors.red.shade50 : null,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                  ),
                                                  if (description != null && description.isNotEmpty)
                                                    Text(description),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.flag, color: _getStageStatusColor(status)),
                                                      const SizedBox(width: 4),
                                                      Text(_stageStatusName(status)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text('${startStr ?? '?'} — ${endStr ?? '?'}'),
                                                  if (isOverdue)
                                                    const Text(
                                                      '⚠ ПРОСРОЧЕНО',
                                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  LinearProgressIndicator(
                                                    value: stageProgress,
                                                    backgroundColor: Colors.grey[300],
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

  Future<double> _calculateOverallProgress(String projectId) async {
    try {
      final stageIdsData = await _supabase
          .from('stages')
          .select('id')
          .eq('project_id', projectId);

      if (stageIdsData.isEmpty) return 0.0;

      final stageIds = stageIdsData.map((s) => s['id'] as String).toList();

      final worksData = await _supabase
          .from('works')
          .select('status')
          .inFilter('stage_id', stageIds);

      if (worksData.isEmpty) return 0.0;

      final total = worksData.length;
      final done = worksData.where((w) => w['status'] == WorkStatus.done.name).length;

      return done / total;
    } catch (e) {
      debugPrint('Ошибка расчёта общего прогресса: $e');
      return 0.0;
    }
  }

  Future<double> _calculateStageProgress(String stageId) async {
    try {
      final worksData = await _supabase
          .from('works')
          .select('status')
          .eq('stage_id', stageId);

      if (worksData.isEmpty) return 0.0;

      final total = worksData.length;
      final done = worksData.where((w) => w['status'] == WorkStatus.done.name).length;

      return done / total;
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
}