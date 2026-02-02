import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class MyTasksTab extends StatefulWidget {
  const MyTasksTab({super.key});

  @override
  State<MyTasksTab> createState() => _MyTasksTabState();
}

class _MyTasksTabState extends State<MyTasksTab>
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

  List<Map<String, dynamic>> _allWorks = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _loadMyProjects();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
      await _supabase
          .from('works')
          .update({'progress': newProgress})
          .eq('id', taskId);

      setState(() {
        final taskIndex = _allWorks.indexWhere((w) => w['id'] == taskId);
        if (taskIndex != -1) _allWorks[taskIndex]['progress'] = newProgress;
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
      await _supabase
          .from('works')
          .update({'status': newStatus.name})
          .eq('id', taskId);

      setState(() {
        final taskIndex = _allWorks.indexWhere((w) => w['id'] == taskId);
        if (taskIndex != -1) _allWorks[taskIndex]['status'] = newStatus.name;
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.percent_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task['name'] ?? 'Прогресс задачи',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 10,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 14,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 28,
                      ),
                    ),
                    child: Slider(
                      value: currentProgress,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: '${currentProgress.toInt()}%',
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor:
                          Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      onChanged: (value) {
                        setDialogState(() => currentProgress = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${currentProgress.toInt()}%',
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'выполнено',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Сохранить'),
                  onPressed: () async {
                    await _updateProgress(
                      task['id'] as String,
                      currentProgress,
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(WorkStatus status) {
    return switch (status) {
      WorkStatus.todo => Colors.grey.shade600,
      WorkStatus.in_progress => Colors.blue.shade600,
      WorkStatus.done => Colors.green.shade700,
      WorkStatus.delayed => Colors.red.shade700,
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

  Widget _buildFilterCard<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<T?>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          isExpanded: true,
          underline: const SizedBox(),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.04),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.task_alt_rounded,
                        size: 28,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Мои задачи',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // Фильтры
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterCard<Map<String, dynamic>>(
                            value: _selectedProject,
                            hint: 'Проект',
                            items: _projects
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p['name'] as String),
                                  ),
                                )
                                .toList(),
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
                          child: _buildFilterCard<Map<String, dynamic>>(
                            value: _selectedStage,
                            hint: 'Этап',
                            items: _stages
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s['name'] as String),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedStage = value),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        labelText: 'Поиск по названию задачи',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterCard<WorkStatus?>(
                            value: _selectedStatusFilter,
                            hint: 'Все статусы',
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Все'),
                              ),
                              ...WorkStatus.values.map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getStatusColor(s),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_workStatusName(s)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedStatusFilter = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilterChip(
                          label: const Text('Просроченные'),
                          selected: _showOverdueOnly,
                          onSelected: (val) =>
                              setState(() => _showOverdueOnly = val),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          selectedColor: Colors.red.shade100,
                          checkmarkColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: _showOverdueOnly
                                ? Colors.red.shade300
                                : Colors.transparent,
                          ),
                          avatar: _showOverdueOnly
                              ? const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: Colors.red,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Список задач
              Expanded(
                child: _selectedStage == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt_rounded,
                              size: 80,
                              color: colorScheme.primary.withOpacity(0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Выберите этап',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Чтобы увидеть ваши задачи',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
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
                              child: Text('Ошибка: ${snapshot.error}'),
                            );
                          }

                          _allWorks = snapshot.data ?? [];

                          // Запускаем анимацию появления списка (если захочешь вернуть FadeTransition)
                          if (snapshot.hasData &&
                              _animController.status == AnimationStatus.dismissed) {
                            _animController.forward(from: 0.0);
                          }

                          final now = DateTime.now();

                          final filtered = _allWorks.where((w) {
                            final nameMatch = (w['name'] as String? ?? '')
                                .toLowerCase()
                                .contains(_searchQuery);
                            final statusMatch = _selectedStatusFilter == null ||
                                w['status'] == _selectedStatusFilter?.name;
                            final overdueMatch = !_showOverdueOnly ||
                                (w['end_date'] != null &&
                                    DateTime.tryParse(w['end_date'] as String)
                                        ?.isBefore(now) ==
                                        true &&
                                    w['status'] != WorkStatus.done.name);

                            return nameMatch && statusMatch && overdueMatch;
                          }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.playlist_remove_rounded,
                                    size: 80,
                                    color: colorScheme.primary.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Нет задач',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'По вашему запросу ничего не найдено'
                                        : 'На этом этапе пока нет задач',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Здесь убрана FadeTransition — карточки теперь видны сразу
                          // Если хочешь вернуть плавное появление → раскомментируй FadeTransition
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final work = filtered[index];
                              final progress =
                                  (work['progress'] as num?)?.toDouble() ?? 0.0;
                              final progressColor = progress < 30
                                  ? Colors.red.shade600
                                  : progress < 70
                                      ? Colors.orange.shade600
                                      : Colors.green.shade600;

                              final status = WorkStatus.values.firstWhere(
                                (e) =>
                                    e.name ==
                                    (work['status'] as String? ?? 'todo'),
                                orElse: () => WorkStatus.todo,
                              );

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                child: Card(
                                  elevation: 4,
                                  shadowColor: Colors.black.withOpacity(0.12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Название + описание
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status)
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Icon(
                                                Icons.task_rounded,
                                                color: _getStatusColor(status),
                                                size: 32,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    work['name'] as String? ??
                                                        'Без названия',
                                                    style: theme
                                                        .textTheme.titleLarge
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (work['description'] !=
                                                          null &&
                                                      (work['description']
                                                              as String)
                                                          .isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 6),
                                                      child: Text(
                                                        work['description']
                                                            as String,
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: theme
                                                            .textTheme.bodyMedium
                                                            ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 24),
                                        // БЛОК УПРАВЛЕНИЯ
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color:
                                                  colorScheme.outlineVariant,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  // Статус
                                                  GestureDetector(
                                                    onTap: () {
                                                      showModalBottomSheet(
                                                        context: context,
                                                        shape:
                                                            const RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .vertical(
                                                            top: Radius
                                                                .circular(24),
                                                          ),
                                                        ),
                                                        builder: (context) =>
                                                            Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .fromLTRB(
                                                            16,
                                                            24,
                                                            16,
                                                            40,
                                                          ),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Изменить статус задачи',
                                                                style: theme
                                                                    .textTheme
                                                                    .titleLarge
                                                                    ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 16),
                                                              ...WorkStatus
                                                                  .values
                                                                  .map((s) {
                                                                final isSelected =
                                                                    status == s;
                                                                return ListTile(
                                                                  leading:
                                                                      Container(
                                                                    width: 28,
                                                                    height: 28,
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      shape: BoxShape
                                                                          .circle,
                                                                      color:
                                                                          _getStatusColor(
                                                                              s),
                                                                    ),
                                                                  ),
                                                                  title: Text(
                                                                    _workStatusName(
                                                                        s),
                                                                    style: TextStyle(
                                                                      fontWeight:
                                                                          isSelected
                                                                              ? FontWeight
                                                                                  .bold
                                                                              : null,
                                                                    ),
                                                                  ),
                                                                  selected:
                                                                      isSelected,
                                                                  selectedTileColor:
                                                                      _getStatusColor(
                                                                              s)
                                                                          .withOpacity(
                                                                              0.15),
                                                                  onTap: () {
                                                                    _updateStatus(
                                                                      work['id']
                                                                          as String,
                                                                      s,
                                                                    );
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                );
                                                              }),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 20,
                                                        vertical: 12,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _getStatusColor(
                                                                    status)
                                                                .withOpacity(
                                                                    0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 16,
                                                            height: 16,
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color:
                                                                  _getStatusColor(
                                                                      status),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 12),
                                                          Text(
                                                            _workStatusName(
                                                                status),
                                                            style: TextStyle(
                                                              color:
                                                                  _getStatusColor(
                                                                      status),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Icon(
                                                            Icons
                                                                .arrow_drop_down_rounded,
                                                            color:
                                                                _getStatusColor(
                                                                    status),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),

                                                  // Прогресс
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _showProgressDialog(
                                                            work),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 20,
                                                        vertical: 12,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: progressColor
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .percent_rounded,
                                                            color: progressColor,
                                                            size: 22,
                                                          ),
                                                          const SizedBox(
                                                              width: 12),
                                                          Text(
                                                            '${progress.toInt()}%',
                                                            style: TextStyle(
                                                              color:
                                                                  progressColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 18,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 16),

                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: LinearProgressIndicator(
                                                  value: progress / 100,
                                                  minHeight: 12,
                                                  backgroundColor: colorScheme
                                                      .surfaceContainerHighest,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(progressColor),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Сроки
                                        if (work['start_date'] != null ||
                                            work['end_date'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 16),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 18,
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Сроки: ${work['start_date'] ?? '?'} — ${work['end_date'] ?? '?'}',
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );

                          // Если хочешь вернуть анимацию появления — раскомментируй:
                          /*
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: ListView.separated(
                              ...
                            ),
                          );
                          */
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}