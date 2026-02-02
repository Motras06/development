import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/enums.dart';

class FilterControls extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ProjectStatus? selectedStatus;
  final ValueChanged<ProjectStatus?> onStatusChanged;

  const FilterControls({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по названию проекта',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilterChip(
                label: const Text('Все'),
                selected: selectedStatus == null,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onStatusChanged(null);
                },
                backgroundColor: colorScheme.surface,
                selectedColor: colorScheme.primary.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: selectedStatus == null
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: selectedStatus == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),

              ...ProjectStatus.values.map((status) {
                final isSelected = selectedStatus == status;
                final statusName = _statusDisplayName(status);
                final statusColor = _getStatusColor(status);

                return FilterChip(
                  label: Text(statusName),
                  selected: isSelected,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onStatusChanged(isSelected ? null : status);
                  },
                  selectedColor: statusColor.withOpacity(0.2),
                  checkmarkColor: statusColor,
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: statusColor.withOpacity(0.3)),
                  avatar: isSelected
                      ? CircleAvatar(
                          backgroundColor: statusColor,
                          radius: 8,
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        )
                      : null,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? statusColor
                        : colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  String _statusDisplayName(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => 'Активный',
      ProjectStatus.paused => 'Приостановлен',
      ProjectStatus.archived => 'Архивирован',
      ProjectStatus.completed => 'Завершён',
    };
  }

  Color _getStatusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => Colors.green,
      ProjectStatus.paused => Colors.orange,
      ProjectStatus.archived => Colors.grey,
      ProjectStatus.completed => Colors.blue,
    };
  }
}
