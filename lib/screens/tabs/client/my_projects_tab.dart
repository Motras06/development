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
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                labelText: 'Поиск по названию проекта',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
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

                final projectIds = participants.map((p) => p['project_id'] as String).toList();

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

                    if (_searchQuery.isNotEmpty) {
                      projects = projects.where((p) {
                        final name = (p['name'] as String?)?.toLowerCase() ?? '';
                        return name.contains(_searchQuery);
                      }).toList();
                    }

                    if (projects.isEmpty) {
                      return const Center(child: Text('Проекты не найдены по запросу'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final name = project['name'] as String? ?? 'Без названия';
                        final description = project['description'] as String?;
                        final statusStr = project['status'] as String? ?? 'active';
                        final startDate = project['start_date'] as String?;
                        final endDate = project['end_date'] as String?;
                        final manualProgress = (project['manual_progress'] as num?)?.toDouble() ?? 0.0;

                        // Нормализуем прогресс (если в БД >100 или <0)
                        final double progress = manualProgress.clamp(0.0, 100.0);

                        // Цвет прогресс-бара
                        final progressColor = progress < 30
                            ? Colors.red
                            : progress < 70
                                ? Colors.orange
                                : Colors.green;

                        // Роль в проекте
                        final participant = participants.firstWhere(
                          (p) => p['project_id'] == project['id'],
                          orElse: () => {'role': 'worker'},
                        );
                        final roleStr = participant['role'] as String;
                        final role = ParticipantRole.values.firstWhere(
                          (r) => r.name == roleStr,
                          orElse: () => ParticipantRole.worker,
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Открыть проект: $name')),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: _getRoleColor(role),
                                        radius: 24,
                                        child: Text(
                                          role.name[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (description != null && description.isNotEmpty)
                                              Text(
                                                description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: Colors.grey[700]),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Статус + Прогресс
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.flag, size: 16, color: _getStatusColor(statusStr)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Статус: ${_projectStatusName(statusStr)}',
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${progress.toInt()}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: progressColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  LinearProgressIndicator(
                                    value: progress / 100, // Для индикатора нужно 0.0–1.0
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                    minHeight: 10,
                                    borderRadius: BorderRadius.circular(5),
                                  ),

                                  const SizedBox(height: 12),

                                  if (startDate != null || endDate != null)
                                    Text(
                                      'Сроки: ${startDate ?? 'Не указана'} — ${endDate ?? 'Не указана'}',
                                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                    ),
                                ],
                              ),
                            ),
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