import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class MyProjectsTab extends StatefulWidget {
  const MyProjectsTab({super.key});

  @override
  State<MyProjectsTab> createState() => _MyProjectsTabState();
}

class _MyProjectsTabState extends State<MyProjectsTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text('Ошибка авторизации'));
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                labelText: 'Поиск по названию проекта',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Только по user_id — один фильтр, работает всегда
              stream: _supabase
                  .from('public.project_participants:user_id=eq.$userId')
                  .stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Ошибка загрузки: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final participants = snapshot.data ?? [];

                // Фильтруем по роли client на клиенте
                final clientParticipants = participants.where((p) {
                  return p['role'] == ParticipantRole.client.name;
                }).toList();

                if (clientParticipants.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Нет проектов',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Вы пока не участвуете ни в одном проекте как заказчик',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final projectIds = clientParticipants
                    .map((p) => p['project_id'] as String)
                    .toSet()
                    .toList();

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('projects')
                      .stream(primaryKey: ['id'])
                      .inFilter('id', projectIds),
                  builder: (context, projectSnapshot) {
                    if (projectSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (projectSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Ошибка проектов: ${projectSnapshot.error}',
                        ),
                      );
                    }

                    var projects = projectSnapshot.data ?? [];

                    // Поиск по названию
                    if (_searchQuery.isNotEmpty) {
                      projects = projects.where((p) {
                        return (p['name'] as String).toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );
                      }).toList();
                    }

                    if (projects.isEmpty) {
                      return const Center(child: Text('Проекты не найдены'));
                    }

                    // Сортировка по дате создания (новые сверху)
                    projects.sort((a, b) {
                      final dateA =
                          DateTime.tryParse(a['created_at'] ?? '') ??
                          DateTime(1970);
                      final dateB =
                          DateTime.tryParse(b['created_at'] ?? '') ??
                          DateTime(1970);
                      return dateB.compareTo(dateA);
                    });

                    return ListView.builder(
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final projectId = project['id'] as String;
                        final name = project['name'] as String;
                        final description = project['description'] as String?;
                        final statusStr = project['status'] as String;
                        final startDate = project['start_date'] as String?;
                        final endDate = project['end_date'] as String?;

                        final status = ProjectStatus.values.firstWhere(
                          (e) => e.name == statusStr,
                          orElse: () => ProjectStatus.active,
                        );

                        return FutureBuilder<double>(
                          future: _calculateProjectProgress(projectId),
                          builder: (context, progressSnapshot) {
                            final progress = progressSnapshot.data ?? 0.0;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: 4,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(status),
                                  child: Text(
                                    status.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (description != null &&
                                        description.isNotEmpty)
                                      Text(
                                        description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.flag,
                                          size: 16,
                                          color: _getStatusColor(status),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Статус: ${_projectStatusName(status)}',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${startDate ?? '?'} — ${endDate ?? '?'}',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'Прогресс: ${(progress * 100).toInt()}%',
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.grey[300],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  progress >= 1.0
                                                      ? Colors.green
                                                      : Colors.blue,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Открыть проект: $name'),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
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

  Future<double> _calculateProjectProgress(String projectId) async {
    try {
      final stageIds = await _supabase
          .from('stages')
          .select('id')
          .eq('project_id', projectId)
          .then((data) => data.map((s) => s['id'] as String).toList());

      if (stageIds.isEmpty) return 0.0;

      final worksData = await _supabase
          .from('works')
          .select('status')
          .inFilter('stage_id', stageIds);

      if (worksData.isEmpty) return 0.0;

      final total = worksData.length;
      final done = worksData
          .where((w) => w['status'] == WorkStatus.done.name)
          .length;

      return done / total;
    } catch (e) {
      debugPrint('Ошибка прогресса: $e');
      return 0.0;
    }
  }

  Color _getStatusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => Colors.green,
      ProjectStatus.paused => Colors.orange,
      ProjectStatus.archived => Colors.grey,
      ProjectStatus.completed => Colors.blue,
    };
  }

  String _projectStatusName(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => 'Активный',
      ProjectStatus.paused => 'Приостановлен',
      ProjectStatus.archived => 'Архивирован',
      ProjectStatus.completed => 'Завершён',
    };
  }
}
