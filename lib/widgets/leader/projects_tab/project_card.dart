import 'package:development/widgets/leader/projects_tab/create_project_dialog.dart'
    show CreateProjectDialog;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class ProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectCard({super.key, required this.project});

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  final _supabase = Supabase.instance.client;

  double get progress {
    final val = widget.project['manual_progress'] as num?;
    return (val ?? 0).toDouble() / 100;
  }

  void _editProject() {
    CreateProjectDialog.show(context, projectToEdit: widget.project);
    // больше не нужно пересчитывать — значение придёт со стримом
  }

  void _showProjectDetails() {
    final name = widget.project['name'] as String;
    final description = widget.project['description'] as String?;
    final statusStr = widget.project['status'] as String;
    final startDate = widget.project['start_date'] as String?;
    final endDate = widget.project['end_date'] as String?;
    final createdAt = widget.project['created_at'] as String?;

    final status = ProjectStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ProjectStatus.active,
    );

    final statusColor = _getStatusColor(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(context);
                      _editProject();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusDisplayName(status),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              if (description != null && description.isNotEmpty)
                Text(description, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Начало: ${startDate ?? 'не указано'}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Окончание: ${endDate ?? 'не указано'}'),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 12),
                    Text('Создан: ${createdAt.split('T')[0]}'),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Прогресс: ${(progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                minHeight: 10,
                borderRadius: BorderRadius.circular(8),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Закрыть'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _editProject,
                      child: const Text('Редактировать'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final name = widget.project['name'] as String;
    final description = widget.project['description'] as String?;
    final statusStr = widget.project['status'] as String;
    final start = widget.project['start_date'] as String?;
    final end = widget.project['end_date'] as String?;

    final status = ProjectStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ProjectStatus.active,
    );

    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: statusColor.withOpacity(0.25), width: 1.2),
      ),
      child: Dismissible(
        key: ValueKey(widget.project['id']),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete, color: Colors.red, size: 36),
        ),
        confirmDismiss: (direction) async {
          HapticFeedback.heavyImpact();
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удалить проект?'),
              content: const Text(
                'Все этапы, работы и связанные данные будут удалены без возможности восстановления.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );

          if (confirm != true) return false;

          try {
            await _supabase.from('projects').delete().eq('id', widget.project['id']);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Проект удалён')),
              );
            }
            return true;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка удаления: $e')),
              );
            }
            return false;
          }
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showProjectDetails,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor,
                  radius: 22,
                  child: Text(
                    status.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (description != null && description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.75),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.flag, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            _statusDisplayName(status),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (start != null || end != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 15,
                                color: colorScheme.onSurface.withOpacity(0.65),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${start ?? '—'} – ${end ?? '—'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3.5,
                        backgroundColor: colorScheme.primary.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active    => Colors.green,
      ProjectStatus.paused    => Colors.orange,
      ProjectStatus.archived  => Colors.grey,
      ProjectStatus.completed => Colors.blue,
    };
  }

  String _statusDisplayName(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active    => 'Активный',
      ProjectStatus.paused    => 'На паузе',
      ProjectStatus.archived  => 'В архиве',
      ProjectStatus.completed => 'Завершён',
    };
  }
}