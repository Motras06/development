import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class MyTasksTab extends StatefulWidget {
  const MyTasksTab({super.key});

  @override
  State<MyTasksTab> createState() => _MyTasksTabState();
}

class _MyTasksTabState extends State<MyTasksTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  WorkStatus? _selectedStatus;
  bool _showOverdueOnly = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text('Ошибка авторизации'));
    }

    return Scaffold(
      body: Column(
        children: [
          // Фильтры
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    labelText: 'Поиск по названию задачи',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<WorkStatus?>(
                        value: _selectedStatus,
                        hint: const Text('Статус'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Все')),
                          ...WorkStatus.values.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(_workStatusName(s)),
                              )),
                        ],
                        onChanged: (value) => setState(() => _selectedStatus = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _showOverdueOnly ? Icons.timer_off : Icons.timer,
                        color: _showOverdueOnly ? Colors.red : null,
                      ),
                      tooltip: 'Просроченные',
                      onPressed: () => setState(() => _showOverdueOnly = !_showOverdueOnly),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Список задач
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('works')
                  .stream(primaryKey: ['id'])
                  .eq('assigned_to', userId!)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final works = snapshot.data ?? [];

                if (works.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Нет задач',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Пока вам не назначено ни одной работы',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final now = DateTime.now();

                // Фильтрация
                final filtered = works.where((w) {
                  final nameMatch = (w['name'] as String)
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                  final statusMatch = _selectedStatus == null ||
                      w['status'] == _selectedStatus?.name;
                  final overdueMatch = !_showOverdueOnly ||
                      (w['end_date'] != null &&
                          DateTime.tryParse(w['end_date'])?.isBefore(now) == true &&
                          w['status'] != WorkStatus.done.name);

                  return nameMatch && statusMatch && overdueMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Задачи не найдены по фильтрам'));
                }

                // Группируем по проекту и этапу
                final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};

                for (final work in filtered) {
                  final stageId = work['stage_id'] as String?;
                  if (stageId == null) continue;

                  // Получаем этап и проект (можно оптимизировать одним запросом, но для простоты — отдельно)
                  final stageFuture = _supabase
                      .from('stages')
                      .select('name, project_id, projects(name)')
                      .eq('id', stageId)
                      .single();

                  // В реальном приложении лучше делать join, но для примера оставим так
                  // (или использовать RPC)
                  // Пока используем заглушки
                  final projectName = 'Проект #${work['stage_id'].toString().substring(0, 8)}';
                  final stageName = 'Этап #${work['stage_id'].toString().substring(0, 8)}';

                  grouped.putIfAbsent(projectName, () => {});
                  grouped[projectName]!.putIfAbsent(stageName, () => []);
                  grouped[projectName]![stageName]!.add(work);
                }

                return ListView(
                  children: grouped.entries.map((projectEntry) {
                    final projectName = projectEntry.key;
                    final stages = projectEntry.value;

                    return ExpansionTile(
                      title: Text(
                        projectName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      children: stages.entries.map((stageEntry) {
                        final stageName = stageEntry.key;
                        final tasks = stageEntry.value;

                        return ExpansionTile(
                          leading: const Icon(Icons.folder),
                          title: Text(stageName),
                          children: tasks.map((task) {
                            final name = task['name'] as String;
                            final description = task['description'] as String?;
                            final statusStr = task['status'] as String;
                            final start = task['start_date'] as String?;
                            final end = task['end_date'] as String?;

                            final status = WorkStatus.values.firstWhere(
                              (e) => e.name == statusStr,
                              orElse: () => WorkStatus.todo,
                            );

                            final isOverdue = end != null &&
                                DateTime.tryParse(end)?.isBefore(now) == true &&
                                status != WorkStatus.done;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              color: isOverdue ? Colors.red.shade50 : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(status),
                                  child: Text(status.name[0].toUpperCase()),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isOverdue ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (description != null && description.isNotEmpty)
                                      Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Статус: ${_workStatusName(status)}',
                                      style: TextStyle(color: _getStatusColor(status)),
                                    ),
                                    Text('Сроки: ${start ?? '?'} — ${end ?? '?'}'),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value.startsWith('status_')) {
                                      final newStatus = value.replaceFirst('status_', '');
                                      await _supabase
                                          .from('works')
                                          .update({'status': newStatus})
                                          .eq('id', task['id']);
                                    } else if (value == 'edit_dates') {
                                      _editTaskDates(task);
                                    } else if (value == 'comment') {
                                      _addComment(task['id']);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    ...WorkStatus.values.map((s) => PopupMenuItem(
                                          value: 'status_${s.name}',
                                          child: Text('Статус: ${_workStatusName(s)}'),
                                        )),
                                    const PopupMenuItem(value: 'edit_dates', child: Text('Изменить сроки')),
                                    const PopupMenuItem(value: 'comment', child: Text('Добавить комментарий')),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _editTaskDates(Map<String, dynamic> task) async {
    DateTime? newStart;
    DateTime? newEnd;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить сроки'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(newStart == null ? 'Новая дата начала' : newStart!.toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime(2030),
                );
                if (picked != null) newStart = picked;
              },
            ),
            ListTile(
              title: Text(newEnd == null ? 'Новая дата окончания' : newEnd!.toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (picked != null) newEnd = picked;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              try {
                await _supabase.from('works').update({
                  if (newStart != null) 'start_date': newStart!.toIso8601String().split('T').first,
                  if (newEnd != null) 'end_date': newEnd!.toIso8601String().split('T').first,
                }).eq('id', task['id']);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _addComment(String workId) async {
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить комментарий'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(hintText: 'Ваш комментарий'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              if (commentController.text.trim().isEmpty) return;

              try {
                await _supabase.from('comments').insert({
                  'entity_type': CommentEntityType.work.name,
                  'entity_id': workId,
                  'user_id': userId,
                  'text': commentController.text.trim(),
                });
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(WorkStatus status) {
    return switch (status) {
      WorkStatus.todo => Colors.grey,
      WorkStatus.in_progress => Colors.blue,
      WorkStatus.done => Colors.green,
      WorkStatus.delayed => Colors.red,
    };
  }

  String _workStatusName(WorkStatus status) {
    return switch (status) {
      WorkStatus.todo => 'К выполнению',
      WorkStatus.in_progress => 'В работе',
      WorkStatus.done => 'Выполнено',
      WorkStatus.delayed => 'Просрочено',
    };
  }
}