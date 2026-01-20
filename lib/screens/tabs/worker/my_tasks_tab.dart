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

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _stages = [];
  Map<String, dynamic>? _selectedProject;
  Map<String, dynamic>? _selectedStage;
  WorkStatus? _selectedStatusFilter;
  bool _showOverdueOnly = false;
  String _searchQuery = '';

  // Локальный кэш всех задач для мгновенного обновления
  List<Map<String, dynamic>> _allWorks = [];

  @override
  void initState() {
    super.initState();
    _loadMyProjects();
  }

  Future<void> _loadMyProjects() async {
    if (userId == null) return;

    try {
      final participantData = await _supabase
          .from('project_participants')
          .select('project_id, projects(id, name)')
          .eq('user_id', userId!);

      final myProjects = participantData
          .map((e) => e['projects'] as Map<String, dynamic>)
          .toList();

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

  Future<void> _updateProgress(String taskId, double newProgress) async {
    try {
      await _supabase.from('works').update({'progress': newProgress}).eq('id', taskId);

      // Мгновенное обновление локального состояния
      setState(() {
        final taskIndex = _allWorks.indexWhere((w) => w['id'] == taskId);
        if (taskIndex != -1) {
          _allWorks[taskIndex]['progress'] = newProgress;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления прогресса: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(String taskId, WorkStatus newStatus) async {
    try {
      await _supabase.from('works').update({'status': newStatus.name}).eq('id', taskId);

      // Мгновенное обновление локального состояния
      setState(() {
        final taskIndex = _allWorks.indexWhere((w) => w['id'] == taskId);
        if (taskIndex != -1) {
          _allWorks[taskIndex]['status'] = newStatus.name;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка смены статуса: $e')),
        );
      }
    }
  }

  void _showProgressDialog(Map<String, dynamic> task) {
    double currentProgress = (task['progress'] as num?)?.toDouble() ?? 0.0;
    final progressController = TextEditingController(text: currentProgress.toInt().toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Прогресс: ${task['name'] ?? 'Без названия'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: currentProgress,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${currentProgress.toInt()}%',
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (value) {
                setState(() => currentProgress = value);
                progressController.text = value.toInt().toString();
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: TextField(
                controller: progressController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(suffixText: '%'),
                onChanged: (value) {
                  final numVal = double.tryParse(value) ?? 0.0;
                  setState(() => currentProgress = numVal.clamp(0.0, 100.0));
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _updateProgress(task['id'] as String, currentProgress);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
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
            // Выбор проекта и этапа
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<Map<String, dynamic>?>(
                      value: _selectedProject,
                      hint: const Text('Выберите проект'),
                      isExpanded: true,
                      items: _projects.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(p['name'] as String),
                        );
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<Map<String, dynamic>?>(
                      value: _selectedStage,
                      hint: const Text('Выберите этап'),
                      isExpanded: true,
                      items: _stages.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedStage = value),
                    ),
                  ),
                ],
              ),
            ),

            // Фильтры
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                    decoration: InputDecoration(
                      labelText: 'Поиск по названию работы',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<WorkStatus?>(
                          value: _selectedStatusFilter,
                          hint: const Text('Все статусы'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Все')),
                            ...WorkStatus.values.map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(_workStatusName(s)),
                                )),
                          ],
                          onChanged: (value) => setState(() => _selectedStatusFilter = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Просроченные'),
                        selected: _showOverdueOnly,
                        onSelected: (val) => setState(() => _showOverdueOnly = val),
                        backgroundColor: _showOverdueOnly ? Colors.red.shade100 : null,
                        selectedColor: Colors.red.shade200,
                        checkmarkColor: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Список работ
            Expanded(
              child: _selectedStage == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 80,
                            color: colorScheme.primary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Выберите этап',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Чтобы увидеть список работ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
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

                        // Обновляем локальный кэш
                        _allWorks = snapshot.data ?? [];

                        final now = DateTime.now();

                        final filtered = _allWorks.where((w) {
                          final nameMatch = (w['name'] as String? ?? '')
                              .toLowerCase()
                              .contains(_searchQuery);
                          final statusMatch = _selectedStatusFilter == null ||
                              w['status'] == _selectedStatusFilter?.name;
                          final overdueMatch = !_showOverdueOnly ||
                              (w['end_date'] != null &&
                                  DateTime.tryParse(w['end_date'] as String)?.isBefore(now) == true &&
                                  w['status'] != WorkStatus.done.name);

                          return nameMatch && statusMatch && overdueMatch;
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 80,
                                  color: colorScheme.primary.withOpacity(0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет работ',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'По вашему запросу ничего не найдено'
                                      : 'На этом этапе пока нет задач',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final work = filtered[index];
                            final progress = (work['progress'] as num?)?.toDouble() ?? 0.0;
                            final progressColor = progress < 30
                                ? Colors.red
                                : progress < 70
                                    ? Colors.orange
                                    : Colors.green;

                            final status = WorkStatus.values.firstWhere(
                              (e) => e.name == (work['status'] as String? ?? 'todo'),
                              orElse: () => WorkStatus.todo,
                            );

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                onTap: () => _showProgressDialog(work),
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(status),
                                    child: Text(status.name[0].toUpperCase()),
                                  ),
                                  title: Text(
                                    work['name'] as String? ?? 'Без названия',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (work['description'] != null && (work['description'] as String).isNotEmpty)
                                        Text(
                                          work['description'] as String,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          DropdownButton<WorkStatus>(
                                            value: status,
                                            underline: const SizedBox(),
                                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                                            items: WorkStatus.values.map((s) {
                                              return DropdownMenuItem(
                                                value: s,
                                                child: Text(
                                                  _workStatusName(s),
                                                  style: TextStyle(color: _getStatusColor(s)),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (newStatus) {
                                              if (newStatus != null) {
                                                _updateStatus(work['id'] as String, newStatus);
                                              }
                                            },
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Прогресс: ${progress.toInt()}%',
                                            style: TextStyle(color: progressColor, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: progress / 100,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                        minHeight: 8,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      if (work['start_date'] != null || work['end_date'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Сроки: ${work['start_date'] ?? '?'} — ${work['end_date'] ?? '?'}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
        ),
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