import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class EditWorkDialog {
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> work,
    required VoidCallback onSaved,
  }) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

// всегда редактируем существующую работу

    final nameController = TextEditingController(text: work['name'] as String);
    final descController = TextEditingController(text: work['description'] as String? ?? '');

    DateTime? startDate = work['start_date'] != null ? DateTime.tryParse(work['start_date']) : null;
    DateTime? endDate = work['end_date'] != null ? DateTime.tryParse(work['end_date']) : null;

    // Статус
    WorkStatus selectedStatus = WorkStatus.values.firstWhere(
      (e) => e.name == (work['status'] as String),
      orElse: () => WorkStatus.todo,
    );

    // Процент завершенности (новое поле — добавим в БД позже)
    // Пока используем условное поле, например work['progress'] или 0..100
    // Для реальной работы нужно добавить колонку numeric progress в таблицу works
    double progress = work['progress'] != null ? (work['progress'] as num).toDouble().clamp(0.0, 100.0) : 0.0;

    final progressController = TextEditingController(text: progress.toInt().toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StatefulBuilder(
          builder: (context, setState) => Padding(
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
                  // Ручка
                  Center(
                    child: Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Редактировать работу',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 28),

                  // Название
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Название работы *',
                      prefixIcon: const Icon(Icons.work_outline),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
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
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Описание',
                      prefixIcon: const Icon(Icons.description_outlined),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Даты
                  Row(
                    children: [
                      Expanded(
                        child: _DateSelector(
                          label: 'Начало',
                          date: startDate,
                          onChanged: (d) => setState(() => startDate = d),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DateSelector(
                          label: 'Окончание',
                          date: endDate,
                          onChanged: (d) => setState(() => endDate = d),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Статус
                  Text('Статус работы', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: WorkStatus.values.map((st) {
                      final isSelected = selectedStatus == st;
                      final color = _getStatusColor(st);

                      return FilterChip(
                        label: Text(
                          _statusName(st),
                          style: TextStyle(
                            color: isSelected ? Colors.white : color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: color.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: color, width: isSelected ? 2 : 1),
                        ),
                        onSelected: (sel) {
                          if (sel) setState(() => selectedStatus = st);
                        },
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Процент завершенности
                  Text('Готовность', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  Slider(
                    value: progress,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${progress.toInt()}%',
                    activeColor: _getStatusColor(selectedStatus),
                    onChanged: (v) {
                      setState(() {
                        progress = v;
                        progressController.text = v.toInt().toString();
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: SizedBox(
                      width: 120,
                      child: TextField(
                        controller: progressController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          suffixText: '%',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) {
                          final numVal = double.tryParse(v) ?? 0;
                          setState(() => progress = numVal.clamp(0.0, 100.0));
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Кнопка сохранить
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: nameController.text.trim().isEmpty
                          ? null
                          : () async {
                              try {
                                final updates = {
                                  'name': nameController.text.trim(),
                                  'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                                  'start_date': startDate?.toIso8601String().split('T')[0],
                                  'end_date': endDate?.toIso8601String().split('T')[0],
                                  'status': selectedStatus.name,
                                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                                  // Поле progress — добавьте в БД!
                                  // 'progress': progress,
                                };

                                await supabase.from('works').update(updates).eq('id', work['id']);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Работа обновлена')),
                                  );
                                  onSaved();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Ошибка сохранения: $e')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Сохранить изменения',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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

  static Color _getStatusColor(WorkStatus status) {
    return switch (status) {
      WorkStatus.todo => Colors.grey.shade700,
      WorkStatus.in_progress => Colors.blue.shade600,
      WorkStatus.done => Colors.green.shade700,
      WorkStatus.delayed => Colors.red.shade700,
    };
  }

  static String _statusName(WorkStatus status) {
    return switch (status) {
      WorkStatus.todo => 'К выполнению',
      WorkStatus.in_progress => 'В работе',
      WorkStatus.done => 'Выполнено',
      WorkStatus.delayed => 'Просрочено',
    };
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  const _DateSelector({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date != null ? date!.toString().split(' ')[0] : label,
                style: TextStyle(
                  color: date != null ? null : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}