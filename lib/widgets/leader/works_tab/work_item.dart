import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class WorkItem extends StatefulWidget {
  final Map<String, dynamic> work;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete;
  final VoidCallback? onUpdated;

  const WorkItem({
    super.key,
    required this.work,
    required this.onStatusChanged,
    required this.onDelete,
    this.onUpdated,
  });

  @override
  State<WorkItem> createState() => _WorkItemState();
}

class _WorkItemState extends State<WorkItem> {
  late Map<String, dynamic> _localWork;

  @override
  void initState() {
    super.initState();
    _localWork = Map.from(widget.work);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = _localWork['name'] as String;
    final description = _localWork['description'] as String?;
    final statusStr = _localWork['status'] as String;
    final start = _localWork['start_date'] as String?;
    final end = _localWork['end_date'] as String?;
    final assignedId = _localWork['assigned_to'] as String?;

    final status = WorkStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => WorkStatus.todo,
    );

    final isOverdue =
        end != null &&
        DateTime.tryParse(end)?.isBefore(DateTime.now()) == true &&
        status != WorkStatus.done;

    final statusColor = _getWorkStatusColor(status, colorScheme);

    final progressValue = (_localWork['progress'] as num?)?.toDouble() ?? 0.0;
    final displayProgress = status == WorkStatus.done
        ? 100.0
        : progressValue.clamp(0.0, 100.0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isOverdue ? 8 : 4,
      shadowColor: isOverdue
          ? Colors.red.withOpacity(0.3)
          : Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: statusColor.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showEditDialog(context),
        child: Dismissible(
          key: ValueKey(_localWork['id']),
          background: Container(
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Spacer(),
                Icon(Icons.check_circle, color: Colors.green, size: 40),
                const SizedBox(width: 20),
              ],
            ),
          ),
          secondaryBackground: Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Icon(Icons.delete, color: Colors.red, size: 40),
                const Spacer(),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              HapticFeedback.heavyImpact();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Удалить работу?'),
                  content: const Text('Это действие нельзя отменить'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Удалить',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                widget.onDelete();
                return true;
              }
            }
            return false;
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: statusColor,
              radius: 20,
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isOverdue ? Colors.red.shade700 : colorScheme.onSurface,
                decoration: isOverdue ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description != null && description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _workStatusName(status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (assignedId != null)
                  FutureBuilder(
                    future: Supabase.instance.client
                        .from('users')
                        .select('full_name, email')
                        .eq('id', assignedId)
                        .maybeSingle(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 8);
                      }

                      final user = snapshot.data;
                      final userName =
                          user?['full_name'] as String? ?? 'Не назначен';
                      final userEmail = user?['email'] as String? ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: colorScheme.primary.withOpacity(
                                0.2,
                              ),
                              child: Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Назначено: $userName${userEmail.isNotEmpty ? ' ($userEmail)' : ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (start != null || end != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${start ?? '?'} — ${end ?? '?'}',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        if (isOverdue)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Просрочено',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${displayProgress.toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: displayProgress / 100,
                    strokeWidth: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: _localWork['name'] as String);
    final descCtrl = TextEditingController(
      text: _localWork['description'] as String? ?? '',
    );

    DateTime? startDate = _localWork['start_date'] != null
        ? DateTime.tryParse(_localWork['start_date'] as String)
        : null;
    DateTime? endDate = _localWork['end_date'] != null
        ? DateTime.tryParse(_localWork['end_date'] as String)
        : null;

    WorkStatus selectedStatus = WorkStatus.values.firstWhere(
      (e) => e.name == (_localWork['status'] as String),
      orElse: () => WorkStatus.todo,
    );

    double progress = (_localWork['progress'] as num?)?.toDouble() ?? 0.0;
    final progressCtrl = TextEditingController(
      text: progress.toInt().toString(),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Редактировать работу',
                    style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Название',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Описание',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text(
                            startDate?.toString().split(' ')[0] ??
                                'Дата начала',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (d != null) setState(() => startDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ListTile(
                          title: Text(
                            endDate?.toString().split(' ')[0] ??
                                'Дата окончания',
                          ),
                          trailing: const Icon(Icons.calendar_today_outlined),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (d != null) setState(() => endDate = d);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Text('Статус', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: WorkStatus.values.map((s) {
                      final chipColor = _getWorkStatusColor(s, colorScheme);
                      return ChoiceChip(
                        label: Text(_workStatusName(s)),
                        selected: selectedStatus == s,
                        selectedColor: chipColor,
                        backgroundColor: chipColor.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: selectedStatus == s ? Colors.white : null,
                        ),
                        onSelected: (_) => setState(() => selectedStatus = s),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Готовность',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  Slider(
                    value: progress,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${progress.toInt()}%',
                    activeColor: _getWorkStatusColor(
                      selectedStatus,
                      colorScheme,
                    ),
                    onChanged: (v) => setState(() {
                      progress = v;
                      progressCtrl.text = v.toInt().toString();
                    }),
                  ),
                  Center(
                    child: SizedBox(
                      width: 100,
                      child: TextField(
                        controller: progressCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(suffixText: '%'),
                        onChanged: (v) {
                          final val = double.tryParse(v) ?? 0;
                          setState(() => progress = val.clamp(0.0, 100.0));
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final updates = {
                            'name': nameCtrl.text.trim(),
                            'description': descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            'start_date': startDate?.toIso8601String().split(
                              'T',
                            )[0],
                            'end_date': endDate?.toIso8601String().split(
                              'T',
                            )[0],
                            'status': selectedStatus.name,
                            'updated_at': DateTime.now()
                                .toUtc()
                                .toIso8601String(),
                            'progress': progress,
                          };

                          await Supabase.instance.client
                              .from('works')
                              .update(updates)
                              .eq('id', widget.work['id']);

                          if (context.mounted) {
                            setState(() {
                              _localWork.addAll({
                                'name': nameCtrl.text.trim(),
                                'description': descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                'start_date': startDate
                                    ?.toIso8601String()
                                    .split('T')[0],
                                'end_date': endDate?.toIso8601String().split(
                                  'T',
                                )[0],
                                'status': selectedStatus.name,
                                'progress': progress,
                              });
                            });

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Работа обновлена')),
                            );
                            widget.onUpdated?.call();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка сохранения: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getWorkStatusColor(WorkStatus status, ColorScheme colorScheme) {
    return switch (status) {
      WorkStatus.todo => Colors.grey,
      WorkStatus.in_progress => Colors.blue,
      WorkStatus.done => colorScheme.primary,
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
