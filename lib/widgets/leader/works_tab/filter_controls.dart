import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/enums.dart';

class FilterControls extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final WorkStatus? selectedStatus;
  final ValueChanged<WorkStatus?> onStatusChanged;
  final bool showOverdueOnly;
  final VoidCallback onOverdueToggled;

  const FilterControls({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.showOverdueOnly,
    required this.onOverdueToggled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          // Поисковое поле с анимацией иконки
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по названию работы',
                hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                prefixIcon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    searchQuery.isEmpty ? Icons.search : Icons.search_off,
                    key: ValueKey(searchQuery.isEmpty),
                    color: colorScheme.primary,
                  ),
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Фильтры в виде Chip'ов
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              // Фильтр по статусу — все статусы в виде Chip
              ...WorkStatus.values.map((status) {
                final isSelected = selectedStatus == status;
                final statusName = _workStatusName(status);
                final statusColor = _getStatusColor(status, colorScheme);

                return FilterChip(
                  label: Text(statusName),
                  selected: isSelected,
                  onSelected: (selected) {
                    HapticFeedback.selectionClick();
                    onStatusChanged(selected ? status : null);
                  },
                  selectedColor: statusColor.withOpacity(0.2),
                  checkmarkColor: statusColor,
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: statusColor.withOpacity(0.3)),
                  avatar: isSelected
                      ? CircleAvatar(
                          backgroundColor: statusColor,
                          radius: 8,
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                        )
                      : null,
                  labelStyle: TextStyle(
                    color: isSelected ? statusColor : colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }),

              // Кнопка "Все"
              FilterChip(
                label: const Text('Все'),
                selected: selectedStatus == null,
                onSelected: (selected) {
                  HapticFeedback.selectionClick();
                  onStatusChanged(null);
                },
                backgroundColor: colorScheme.surface,
                selectedColor: colorScheme.primary.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: selectedStatus == null ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: selectedStatus == null ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),

              // // Переключатель просроченных
              // ActionChip(
              //   label: Text(
              //     'Просроченные',
              //     style: TextStyle(
              //       color: showOverdueOnly ? Colors.white : Colors.red,
              //       fontWeight: showOverdueOnly ? FontWeight.bold : FontWeight.normal,
              //     ),
              //   ),
              //   avatar: Icon(
              //     showOverdueOnly ? Icons.timer_off : Icons.timer,
              //     color: showOverdueOnly ? Colors.white : Colors.red,
              //   ),
              //   backgroundColor: showOverdueOnly ? Colors.red : colorScheme.surface,
              //   side: BorderSide(color: Colors.red.withOpacity(showOverdueOnly ? 1 : 0.5)),
              //   onPressed: () {
              //     HapticFeedback.mediumImpact();
              //     onOverdueToggled();
              //   },
              //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  String _workStatusName(WorkStatus status) {
    return switch (status) {
      WorkStatus.todo => 'К выполнению',
      WorkStatus.in_progress => 'В работе',
      WorkStatus.done => 'Выполнено',
      WorkStatus.delayed => 'Просрочено',
    };
  }

  Color _getStatusColor(WorkStatus status, ColorScheme colorScheme) {
    return switch (status) {
      WorkStatus.todo => Colors.grey,
      WorkStatus.in_progress => Colors.blue,
      WorkStatus.done => colorScheme.primary,
      WorkStatus.delayed => Colors.red,
    };
  }
}