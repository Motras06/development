import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart'; // Твой файл с enum'ами

class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  final _supabase = Supabase.instance.client;
  String _searchQuery = '';
  ProjectStatus? _selectedStatus;

  // Диалог создания нового проекта
  Future<void> _createProject() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать новый проект'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название проекта'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(startDate == null
                    ? 'Дата начала'
                    : startDate!.toString().split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    startDate = picked;
                    setState(() {});
                  }
                },
              ),
              ListTile(
                title: Text(endDate == null
                    ? 'Дата окончания'
                    : endDate!.toString().split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    endDate = picked;
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите название проекта')),
                );
                return;
              }

              try {
                // Создаём проект
                final projectResponse = await _supabase.from('projects').insert({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                  'start_date': startDate?.toIso8601String().split('T').first,
                  'end_date': endDate?.toIso8601String().split('T').first,
                  'status': ProjectStatus.active.name,
                  'created_by': _supabase.auth.currentUser!.id,
                }).select('id').single();

                final projectId = projectResponse['id'];

                // Добавляем себя как leader
                await _supabase.from('project_participants').insert({
                  'project_id': projectId,
                  'user_id': _supabase.auth.currentUser!.id,
                  'role': ParticipantRole.leader.name,
                });

                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка создания проекта: $e')),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return const Center(child: Text('Ошибка авторизации'));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        label: const Text('Новый проект'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Поиск и фильтр по статусу
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: const InputDecoration(
                      labelText: 'Поиск по названию',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<ProjectStatus?>(
                  value: _selectedStatus,
                  hint: const Text('Статус'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все')),
                    ...ProjectStatus.values.map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(_statusDisplayName(status)),
                        )),
                  ],
                  onChanged: (value) => setState(() => _selectedStatus = value),
                ),
              ],
            ),
          ),

          // Список проектов в реальном времени
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('projects')
                  .stream(primaryKey: ['id'])
                  .eq('created_by', userId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final projects = snapshot.data ?? [];

                // Клиентская фильтрация
                final filtered = projects.where((p) {
                  final nameMatch = (p['name'] as String)
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                  final statusMatch = _selectedStatus == null ||
                      p['status'] == _selectedStatus?.name;
                  return nameMatch && statusMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Нет проектов',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Нажмите "+" для создания первого проекта',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final project = filtered[index];
                    final name = project['name'] as String;
                    final description = project['description'] as String?;
                    final statusStr = project['status'] as String;
                    final startDate = project['start_date'] as String?;
                    final endDate = project['end_date'] as String?;

                    // Преобразуем строку статуса в enum
                    final status = ProjectStatus.values.firstWhere(
                      (e) => e.name == statusStr,
                      orElse: () => ProjectStatus.active,
                    );

                    // Заглушка прогресса (потом реализуем реальный расчёт)
                    final double progress = 0.42; // 42%

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 3,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status),
                          child: Text(
                            status.name[0].toUpperCase(),
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
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.flag, size: 16, color: _getStatusColor(status)),
                                const SizedBox(width: 4),
                                Text(
                                  _statusDisplayName(status),
                                  style: TextStyle(color: _getStatusColor(status)),
                                ),
                              ],
                            ),
                            if (startDate != null || endDate != null)
                              Text(
                                '${startDate ?? '?'} — ${endDate ?? '?'}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 4,
                                backgroundColor: Colors.grey[300],
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          // TODO: Открыть детальный экран проекта
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Открыть проект: $name')),
                          );
                        },
                      ),
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

  Color _getStatusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => Colors.green,
      ProjectStatus.paused => Colors.orange,
      ProjectStatus.archived => Colors.grey,
      ProjectStatus.completed => Colors.blue,
    };
  }

  String _statusDisplayName(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => 'Активный',
      ProjectStatus.paused => 'Приостановлен',
      ProjectStatus.archived => 'Архивирован',
      ProjectStatus.completed => 'Завершён',
    };
  }
}