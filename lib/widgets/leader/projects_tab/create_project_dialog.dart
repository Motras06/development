import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class CreateProjectDialog {
  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? projectToEdit,
    VoidCallback? onSuccess,
  }) async {
    final _supabase = Supabase.instance.client;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final isEdit = projectToEdit != null;

    final nameController = TextEditingController(
      text: isEdit ? projectToEdit['name'] : '',
    );
    final descController = TextEditingController(
      text: isEdit ? projectToEdit['description'] ?? '' : '',
    );

    DateTime? startDate = isEdit && projectToEdit['start_date'] != null
        ? DateTime.tryParse(projectToEdit['start_date'])
        : null;
    DateTime? endDate = isEdit && projectToEdit['end_date'] != null
        ? DateTime.tryParse(projectToEdit['end_date'])
        : null;

    double manualProgress = isEdit && projectToEdit['manual_progress'] != null
        ? (projectToEdit['manual_progress'] as num).toDouble().clamp(0.0, 100.0)
        : 0.0;

    final progressTextController = TextEditingController(
      text: manualProgress.toInt().toString(),
    );

    ProjectStatus selectedStatus = isEdit && projectToEdit['status'] != null
        ? ProjectStatus.values.firstWhere(
            (e) => e.name == projectToEdit['status'],
            orElse: () => ProjectStatus.active,
          )
        : ProjectStatus.active;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.95,
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
              bottom: MediaQuery.of(context).viewInsets.bottom + 40,
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
                          context,
                        ).colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    isEdit ? 'Редактировать проект' : 'Новый проект',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Название проекта *',
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
                  const SizedBox(height: 24),

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
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
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
                              initialDate:
                                  endDate ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null)
                              setDialogState(() => endDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Статус проекта',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ProjectStatus.values.map((status) {
                      final isSelected = selectedStatus == status;
                      final color = _getStatusColor(status);

                      return FilterChip(
                        label: Text(
                          _statusDisplayName(status),
                          style: TextStyle(
                            color: isSelected ? Colors.white : color,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: color.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: color,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => selectedStatus = status);
                          }
                        },
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Готовность проекта',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  Slider(
                    value: manualProgress,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${manualProgress.toInt()}%',
                    onChanged: (value) {
                      setDialogState(() {
                        manualProgress = value;
                        progressTextController.text = value.toInt().toString();
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: progressTextController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            suffixText: '%',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onChanged: (val) {
                            final numVal = double.tryParse(val) ?? 0;
                            setDialogState(() {
                              manualProgress = numVal.clamp(0.0, 100.0);
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: nameController.text.trim().isEmpty
                          ? null
                          : () async {
                              try {
                                final data = {
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
                                  'manual_progress': manualProgress,
                                  'status': selectedStatus.name,
                                };

                                if (isEdit) {
                                  await _supabase
                                      .from('projects')
                                      .update(data)
                                      .eq('id', projectToEdit['id']);
                                } else {
                                  final response = await _supabase
                                      .from('projects')
                                      .insert({...data, 'created_by': userId})
                                      .select('id')
                                      .single();

                                  final projectId = response['id'];
                                  await _supabase
                                      .from('project_participants')
                                      .insert({
                                        'project_id': projectId,
                                        'user_id': userId,
                                        'role': ParticipantRole.leader.name,
                                      });
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEdit
                                            ? 'Проект обновлён'
                                            : 'Проект создан',
                                      ),
                                    ),
                                  );

                                  onSuccess?.call();
                                }
                              } catch (e) {
                                if (context.mounted) {
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
                        elevation: 6,
                      ),
                      child: Text(
                        isEdit ? 'Сохранить изменения' : 'Создать проект',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _getStatusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => Colors.green.shade700,
      ProjectStatus.paused => Colors.orange.shade700,
      ProjectStatus.completed => Colors.blue.shade700,
      ProjectStatus.archived => Colors.grey.shade700,
    };
  }

  static String _statusDisplayName(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => 'Активный',
      ProjectStatus.paused => 'На паузе',
      ProjectStatus.completed => 'Завершён',
      ProjectStatus.archived => 'Архивирован',
    };
  }
}
