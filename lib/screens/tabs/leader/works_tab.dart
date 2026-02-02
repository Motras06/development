import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';
import '/widgets/leader/works_tab/filter_controls.dart';
import '/widgets/leader/works_tab/project_dropdown.dart';
import '/widgets/leader/works_tab/stage_dropdown.dart';
import '/widgets/leader/works_tab/work_item.dart';

class WorksTab extends StatefulWidget {
  const WorksTab({super.key});

  @override
  State<WorksTab> createState() => _WorksTabState();
}

class _WorksTabState extends State<WorksTab>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _stages = [];
  Map<String, dynamic>? _selectedProject;
  Map<String, dynamic>? _selectedStage;
  WorkStatus? _selectedStatusFilter;
  bool _showOverdueOnly = false;
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
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool canCreateWork = _selectedStage != null;

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
                    child: ProjectDropdown(
                      projects: _projects,
                      selectedProject: _selectedProject,
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
                    child: StageDropdown(
                      stages: _stages,
                      selectedStage: _selectedStage,
                      onChanged: (value) =>
                          setState(() => _selectedStage = value),
                    ),
                  ),
                ],
              ),
            ),

            FilterControls(
              searchQuery: _searchQuery,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              selectedStatus: _selectedStatusFilter,
              onStatusChanged: (value) =>
                  setState(() => _selectedStatusFilter = value),
              showOverdueOnly: _showOverdueOnly,
              onOverdueToggled: () =>
                  setState(() => _showOverdueOnly = !_showOverdueOnly),
            ),

            const SizedBox(height: 12),

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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Ошибка загрузки работ',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          );
                        }

                        final works = snapshot.data ?? [];

                        final now = DateTime.now();

                        final filtered = works.where((w) {
                          final nameMatch = (w['name'] as String)
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase());
                          final statusMatch =
                              _selectedStatusFilter == null ||
                              w['status'] == _selectedStatusFilter?.name;
                          final overdueMatch =
                              !_showOverdueOnly ||
                              (w['end_date'] != null &&
                                  DateTime.tryParse(
                                        w['end_date'],
                                      )?.isBefore(now) ==
                                      true &&
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
                                    color: colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'По вашему запросу ничего не найдено'
                                      : 'На этом этапе пока нет задач',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final work = filtered[index];

                            return AnimatedSlide(
                              duration: Duration(
                                milliseconds: 300 + index * 50,
                              ),
                              offset: Offset(0, index * 0.05),
                              curve: Curves.easeOutCubic,
                              child: WorkItem(
                                work: work,
                                onStatusChanged: (newStatus) async {
                                  await _supabase
                                      .from('works')
                                      .update({'status': newStatus})
                                      .eq('id', work['id']);
                                },
                                onDelete: () async {
                                  await _supabase
                                      .from('works')
                                      .delete()
                                      .eq('id', work['id']);
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
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), 
        child: ScaleTransition(
          scale: _fabScaleAnimation,
          child: FloatingActionButton.extended(
            onPressed: canCreateWork
                ? () async {
                    await _createWork(context);
                    if (mounted) {
                      _fabAnimationController.reverse().then((_) {
                        _fabAnimationController.forward();
                      });
                    }
                  }
                : null,
            backgroundColor: canCreateWork
                ? colorScheme.primary
                : colorScheme.surface.withOpacity(0.6),
            foregroundColor: canCreateWork
                ? Colors.white
                : colorScheme.onSurface.withOpacity(0.4),
            elevation: canCreateWork ? 12 : 4,
            tooltip: canCreateWork ? 'Создать новую работу' : 'Выберите этап',
            label: const Text(
              'Новая работа',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            icon: const Icon(Icons.add_task, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat, 
    );
  }

  Future<void> _createWork(BuildContext context) async {
    if (_selectedStage == null) return;

    final nameController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    Map<String, dynamic>? assignedUser;

    final participants = await _supabase
        .from('project_participants')
        .select('user_id, users(full_name, email)')
        .eq('project_id', _selectedProject!['id'])
        .eq('role', ParticipantRole.worker.name);

    final workerOptions = participants
        .map((p) => p['users'] as Map<String, dynamic>)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) => Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Новая работа',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Название работы *',
                    prefixIcon: const Icon(Icons.title),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: descController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Описание (опционально)',
                    prefixIcon: const Icon(Icons.description_outlined),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          startDate == null
                              ? 'Дата начала'
                              : startDate!.toString().split(' ')[0],
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme
                                      .copyWith(
                                        primary: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null)
                            setDialogState(() => startDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(
                          endDate == null
                              ? 'Дата окончания'
                              : endDate!.toString().split(' ')[0],
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 7),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme
                                      .copyWith(
                                        primary: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null)
                            setDialogState(() => endDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<Map<String, dynamic>?>(
                  value: assignedUser,
                  hint: const Text('Назначить работнику'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_add),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Не назначено'),
                    ),
                    ...workerOptions.map(
                      (user) => DropdownMenuItem(
                        value: user,
                        child: Text(user['full_name'] ?? user['email']),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => assignedUser = value),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: nameController.text.trim().isEmpty
                        ? null
                        : () async {
                            try {
                              await _supabase.from('works').insert({
                                'stage_id': _selectedStage!['id'],
                                'name': nameController.text.trim(),
                                'description':
                                    descController.text.trim().isEmpty
                                    ? null
                                    : descController.text.trim(),
                                'start_date': startDate
                                    ?.toIso8601String()
                                    .split('T')
                                    .first,
                                'end_date': endDate
                                    ?.toIso8601String()
                                    .split('T')
                                    .first,
                                'status': WorkStatus.todo.name,
                                'assigned_to': assignedUser?['id'],
                              });

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Работа успешно создана!'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ошибка: $e')),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 10,
                    ),
                    child: const Text(
                      'Создать работу',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
