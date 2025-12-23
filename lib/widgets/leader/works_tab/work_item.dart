import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class WorkItem extends StatelessWidget {
  final Map<String, dynamic> work;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete;

  const WorkItem({
    super.key,
    required this.work,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        DateTime.tryParse(end)?.isBefore(DateTime.now()) == true &&
        status != WorkStatus.done;

    // Цвет и стиль для карточки
    final statusColor = _getWorkStatusColor(status, colorScheme);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isOverdue ? 8 : 4,
      shadowColor: isOverdue ? Colors.red.withOpacity(0.3) : Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: statusColor.withOpacity(0.2)),
      ),
      child: Dismissible(
        key: ValueKey(work['id']),
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
            // Swipe влево — удаление
            HapticFeedback.heavyImpact();
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Удалить работу?'),
                content: Text('Это действие нельзя отменить'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              onDelete();
            }
            return false;
          }
          return false;
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: CircleAvatar(
            backgroundColor: statusColor,
            radius: 20,
            child: Text(
              status.name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      .single(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(height: 8);
                    }

                    final user = userSnap.data;
                    final userName = user?['full_name'] as String? ?? 'Работник';
                    final userEmail = user?['email'] as String? ?? 'Нет email';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: colorScheme.primary.withOpacity(0.2),
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Назначено: $userName',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    userEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              if (start != null || end != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: colorScheme.onSurface.withOpacity(0.6)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                '${(status == WorkStatus.done ? 100 : 0)}%',
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
                  value: status == WorkStatus.done ? 1.0 : null,
                  strokeWidth: 3,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
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