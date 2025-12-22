import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class WorksTab extends StatefulWidget {
  const WorksTab({super.key});

  @override
  State<WorksTab> createState() => _WorksTabState();
}

class _WorksTabState extends State<WorksTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _stages = [];
  Map<String, dynamic>? _selectedProject;
  Map<String, dynamic>? _selectedStage;
  WorkStatus? _selectedStatusFilter;
  bool _showOverdueOnly = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final data = await _supabase
          .from('projects')
          .select('id, name')
          .eq('created_by', userId!)
          .order('created_at', ascending: false);

      setState(() {
        _projects = List<Map<String, dynamic>>.from(data);
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

    try {
      final data = await _supabase
          .from('stages')
          .select('id, name')
          .eq('project_id', _selectedProject!['id'])
          .order('created_at');

      setState(() {
        _stages = List<Map<String, dynamic>>.from(data);
        if (_stages.isNotEmpty && _selectedStage == null) {
          _selectedStage = _stages.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки этапов: $e');
    }
  }

  Future<void> _createWork() async {
    if (_selectedStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите этап для создания работы')),
      );
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    Map<String, dynamic>? assignedUser;

    // Получаем список работников проекта
    final participants = await _supabase
        .from('project_participants')
        .select('user_id, users(full_name, email)')
        .eq('project_id', _selectedProject!['id'])
        .eq('role', ParticipantRole.worker.name);

    final workerOptions = participants.map((p) => p['users'] as Map<String, dynamic>).toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новая работа'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название работы'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Описание'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(startDate == null ? 'Дата начала' : startDate!.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                ListTile(
                  title: Text(endDate == null ? 'Дата окончания' : endDate!.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => endDate = picked);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButton<Map<String, dynamic>?>(
                  hint: const Text('Назначить работнику'),
                  value: assignedUser,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Не назначено')),
                    ...workerOptions.map((user) => DropdownMenuItem(
                          value: user,
                          child: Text(user['full_name'] ?? user['email']),
                        )),
                  ],
                  onChanged: (value) => setDialogState(() => assignedUser = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                try {
                  await _supabase.from('works').insert({
                    'stage_id': _selectedStage!['id'],
                    'name': nameController.text.trim(),
                    'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                    'start_date': startDate?.toIso8601String().split('T').first,
                    'end_date': endDate?.toIso8601String().split('T').first,
                    'status': WorkStatus.todo.name,
                    'assigned_to': assignedUser?['id'],
                  });

                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка создания работы: $e')),
                    );
                  }
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createWork,
        label: const Text('Новая работа'),
        icon: const Icon(Icons.add_task),
      ),
      body: Column(
        children: [
          // Выбор проекта и этапа
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<Map<String, dynamic>?>(
                    hint: const Text('Проект'),
                    value: _selectedProject,
                    isExpanded: true,
                    items: _projects.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p['name']));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedProject = value;
                        _selectedStage = null;
                        _stages.clear();
                      });
                      if (value != null) _loadStages();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<Map<String, dynamic>?>(
                    hint: const Text('Этап'),
                    value: _selectedStage,
                    isExpanded: true,
                    items: _stages.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s['name']));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedStage = value),
                  ),
                ),
              ],
            ),
          ),

          // Фильтры
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                DropdownButton<WorkStatus?>(
                  value: _selectedStatusFilter,
                  hint: const Text('Статус'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все')),
                    ...WorkStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(_workStatusName(s)))),
                  ],
                  onChanged: (value) => setState(() => _selectedStatusFilter = value),
                ),
                IconButton(
                  icon: Icon(_showOverdueOnly ? Icons.timer_off : Icons.timer),
                  tooltip: 'Просроченные',
                  color: _showOverdueOnly ? Colors.red : null,
                  onPressed: () => setState(() => _showOverdueOnly = !_showOverdueOnly),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Список работ
          Expanded(
            child: _selectedStage == null
                ? const Center(child: Text('Выберите этап для просмотра работ'))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('works')
                        .stream(primaryKey: ['id'])
                        .eq('stage_id', _selectedStage!['id'])
                        .order('created_at', ascending: false),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Ошибка: ${snapshot.error}'));
                      }

                      final works = snapshot.data ?? [];

                      final now = DateTime.now();

                      final filtered = works.where((w) {
                        final nameMatch = (w['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
                        final statusMatch = _selectedStatusFilter == null || w['status'] == _selectedStatusFilter?.name;
                        final overdueMatch = !_showOverdueOnly ||
                            (w['end_date'] != null &&
                                DateTime.tryParse(w['end_date'])?.isBefore(now) == true &&
                                w['status'] != WorkStatus.done.name);

                        return nameMatch && statusMatch && overdueMatch;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('Нет работ на этом этапе'));
                      }

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final work = filtered[index];
                          final name = work['name'] as String;
                          final description = work['description'] as String?;
                          final statusStr = work['status'] as String;
                          final start = work['start_date'] as String?;
                          final end = work['end_date'] as String?;
                          final assignedId = work['assigned_to'] as String?;

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
                                backgroundColor: _getWorkStatusColor(status),
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
                                    style: TextStyle(color: _getWorkStatusColor(status)),
                                  ),
                                  if (assignedId != null)
                                    FutureBuilder(
                                      future: _supabase
                                          .from('users')
                                          .select('full_name')
                                          .eq('id', assignedId)
                                          .single(),
                                      builder: (context, userSnap) {
                                        final userName = userSnap.data?['full_name'] ?? 'Работник';
                                        return Text('Назначено: $userName');
                                      },
                                    ),
                                  if (start != null || end != null)
                                    Text('${start ?? '?'} — ${end ?? '?'}'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    // Редактирование (заглушка)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Редактировать работу: $name')),
                                    );
                                  } else if (value.startsWith('status_')) {
                                    final newStatus = value.replaceFirst('status_', '');
                                    await _supabase
                                        .from('works')
                                        .update({'status': newStatus})
                                        .eq('id', work['id']);
                                  } else if (value == 'delete') {
                                    await _supabase.from('works').delete().eq('id', work['id']);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                                  ...WorkStatus.values.map((s) => PopupMenuItem(
                                        value: 'status_${s.name}',
                                        child: Text('Статус: ${_workStatusName(s)}'),
                                      )),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
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

  Color _getWorkStatusColor(WorkStatus status) {
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