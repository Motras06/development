import 'package:flutter/material.dart';

class StageDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> stages;
  final Map<String, dynamic>? selectedStage;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const StageDropdown({
    super.key,
    required this.stages,
    required this.selectedStage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool hasSelection = selectedStage != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasSelection ? colorScheme.primary : colorScheme.outline.withOpacity(0.4),
          width: hasSelection ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: hasSelection
                ? colorScheme.primary.withOpacity(0.25)
                : Colors.black.withOpacity(0.05),
            blurRadius: hasSelection ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>?>(
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.view_week_outlined,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Этап',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          value: selectedStage,
          isExpanded: true,
          icon: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: AnimatedRotation(
              turns: hasSelection ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: hasSelection ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                size: 28,
              ),
            ),
          ),
          dropdownColor: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          elevation: 8,
          items: stages.map((stage) {
            final String name = stage['name'] as String;

            return DropdownMenuItem<Map<String, dynamic>?>(
              value: stage,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.view_week,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: hasSelection && selectedStage == stage
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (hasSelection && selectedStage == stage)
                      Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          selectedItemBuilder: (context) {
            return stages.map<Widget>((stage) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.view_week_outlined,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stage['name'],
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}