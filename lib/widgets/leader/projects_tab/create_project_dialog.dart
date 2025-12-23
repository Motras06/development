import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class CreateProjectDialog {
  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? projectToEdit,
  }) async {
    final _supabase = Supabase.instance.client;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final isEdit = projectToEdit != null;

    final nameController = TextEditingController(text: isEdit ? projectToEdit['name'] : '');
    final descController = TextEditingController(text: isEdit ? projectToEdit['description'] ?? '' : '');
    DateTime? startDate = isEdit && projectToEdit['start_date'] != null
        ? DateTime.tryParse(projectToEdit['start_date'])
        : null;
    DateTime? endDate = isEdit && projectToEdit['end_date'] != null
        ? DateTime.tryParse(projectToEdit['end_date'])
        : null;

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
                // Ручка свайпа
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

                // Заголовок
                Text(
                  isEdit ? 'Редактировать проект' : 'Новый проект',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 24),

                // Название
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Название проекта *',
                    prefixIcon: const Icon(Icons.title),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Описание
                TextField(
                  controller: descController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Описание (опционально)',
                    prefixIcon: const Icon(Icons.description_outlined),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Даты
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          startDate == null ? 'Дата начала' : startDate!.toString().split(' ')[0],
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(primary: Theme.of(context).colorScheme.primary),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) setDialogState(() => startDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(
                          endDate == null ? 'Дата окончания' : endDate!.toString().split(' ')[0],
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(primary: Theme.of(context).colorScheme.primary),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) setDialogState(() => endDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Кнопка действия
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: nameController.text.trim().isEmpty
                        ? null
                        : () async {
                            try {
                              final data = {
                                'name': nameController.text.trim(),
                                'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                                'start_date': startDate?.toIso8601String().split('T').first,
                                'end_date': endDate?.toIso8601String().split('T').first,
                              };

                              if (isEdit) {
                                await _supabase
                                    .from('projects')
                                    .update(data)
                                    .eq('id', projectToEdit['id']);
                              } else {
                                final response = await _supabase.from('projects').insert({
                                  ...data,
                                  'status': ProjectStatus.active.name,
                                  'created_by': userId,
                                }).select('id').single();

                                final projectId = response['id'];
                                await _supabase.from('project_participants').insert({
                                  'project_id': projectId,
                                  'user_id': userId,
                                  'role': ParticipantRole.leader.name,
                                });
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isEdit ? 'Проект обновлён' : 'Проект создан')),
                                );
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 10,
                    ),
                    child: Text(
                      isEdit ? 'Сохранить изменения' : 'Создать проект',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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