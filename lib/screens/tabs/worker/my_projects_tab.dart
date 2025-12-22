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
          // Поиск
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

          // Список проектов
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('project_participants')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', userId!)
                  .order('joined_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final participants = snapshot.data ?? [];

                if (participants.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Нет проектов',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Вы пока не участвуете ни в одном проекте',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Получаем ID проектов
                final projectIds = participants.map((p) => p['project_id'] as String).toList();

                // Запрашиваем данные проектов
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('projects')
                      .stream(primaryKey: ['id'])
                      .inFilter('id', projectIds)
                      .order('created_at', ascending: false),
                  builder: (context, projectSnapshot) {
                    if (projectSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (projectSnapshot.hasError) {
                      return Center(child: Text('Ошибка загрузки проектов: ${projectSnapshot.error}'));
                    }

                    var projects = projectSnapshot.data ?? [];

                    // Фильтрация по поиску
                    if (_searchQuery.isNotEmpty) {
                      projects = projects.where((p) {
                        return (p['name'] as String)
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                      }).toList();
                    }

                    if (projects.isEmpty) {
                      return const Center(child: Text('Проекты не найдены по запросу'));
                    }

                    return ListView.builder(
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final name = project['name'] as String;
                        final description = project['description'] as String?;
                        final statusStr = project['status'] as String;
                        final startDate = project['start_date'] as String?;
                        final endDate = project['end_date'] as String?;

                        // Находим роль пользователя в этом проекте
                        final participant = participants.firstWhere(
                          (p) => p['project_id'] == project['id'],
                          orElse: () => {'role': 'worker'},
                        );
                        final roleStr = participant['role'] as String;
                        final role = ParticipantRole.values.firstWhere(
                          (r) => r.name == roleStr,
                          orElse: () => ParticipantRole.worker,
                        );

                        // Заглушка прогресса
                        final double progress = 0.65; // 65%

                        // Текущий этап — заглушка (потом можно взять последний in_progress)
                        final currentStage = 'Фундамент';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 4,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getRoleColor(role),
                              child: Text(
                                role.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (description != null && description.isNotEmpty)
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.flag, size: 16, color: _getStatusColor(statusStr)),
                                    const SizedBox(width: 4),
                                    Text('Статус: ${_projectStatusName(statusStr)}'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Текущий этап: $currentStage'),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Прогресс: ${(progress * 100).toInt()}%'),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          progress > 0.8 ? Colors.green : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (startDate != null || endDate != null)
                                  Text(
                                    'Сроки: ${startDate ?? '?'} — ${endDate ?? '?'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () {
                              // Переход к деталям проекта (потом реализуем)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Открыть проект: $name')),
                              );
                            },
                          ),
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

  Color _getRoleColor(ParticipantRole role) {
    return switch (role) {
      ParticipantRole.leader => Colors.blue,
      ParticipantRole.worker => Colors.green,
      ParticipantRole.client => Colors.orange,
      ParticipantRole.admin => Colors.purple,
    };
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'active' => Colors.green,
      'paused' => Colors.orange,
      'archived' => Colors.grey,
      'completed' => Colors.blue,
      _ => Colors.grey,
    };
  }

  String _projectStatusName(String status) {
    return switch (status) {
      'active' => 'Активный',
      'paused' => 'Приостановлен',
      'archived' => 'Архивирован',
      'completed' => 'Завершён',
      _ => status,
    };
  }
}