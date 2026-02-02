import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeline_tile/timeline_tile.dart';

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  String? _selectedProjectId;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text('Не авторизован'));
    }

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('project_participants')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', userId!)
                      .order('joined_at', ascending: false),
                  builder: (context, participantSnapshot) {
                    if (participantSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox(
                        height: 56,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (participantSnapshot.hasError) {
                      return const SizedBox(
                        height: 56,
                        child: Center(child: Text('Ошибка загрузки')),
                      );
                    }

                    final participants = participantSnapshot.data ?? [];

                    if (participants.isEmpty) {
                      return const SizedBox(
                        height: 56,
                        child: Center(child: Text('Нет проектов')),
                      );
                    }

                    final projectIds = participants
                        .map((p) => p['project_id'] as String)
                        .toList();

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _supabase
                          .from('projects')
                          .stream(primaryKey: ['id'])
                          .inFilter('id', projectIds)
                          .order('created_at', ascending: false),
                      builder: (context, projectSnapshot) {
                        if (projectSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 56,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (projectSnapshot.hasError) {
                          return const SizedBox(
                            height: 56,
                            child: Center(
                              child: Text('Ошибка загрузки проектов'),
                            ),
                          );
                        }

                        final projects = projectSnapshot.data ?? [];

                        if (projects.isEmpty) {
                          return const SizedBox(
                            height: 56,
                            child: Center(child: Text('Проекты не найдены')),
                          );
                        }

                        if (_selectedProjectId == null && projects.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _selectedProjectId =
                                    projects.first['id'] as String;
                              });
                            }
                          });
                        }

                        final selectedProject = projects.firstWhere(
                          (p) => p['id'] == _selectedProjectId,
                          orElse: () => projects.isNotEmpty
                              ? projects.first
                              : <String, dynamic>{},
                        );

                        return DropdownButton<Map<String, dynamic>>(
                          value: selectedProject.isNotEmpty
                              ? selectedProject
                              : null,
                          isExpanded: true,
                          hint: const Text('Выберите проект'),
                          items: projects.map((p) {
                            final participant = participants.firstWhere(
                              (part) => part['project_id'] == p['id'],
                              orElse: () => {'role': 'участник'},
                            );
                            final role =
                                participant['role'] as String? ?? 'участник';
                            final roleName = _formatRole(role);
                            return DropdownMenuItem(
                              value: p,
                              child: Text('${p['name']} • $roleName'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProjectId = value['id'] as String;
                              });
                            }
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                TextField(
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    labelText: 'Поиск по названию этапа',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _selectedProjectId == null
                ? const Center(
                    child: Text(
                      'Выберите проект для просмотра прогресса',
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildStagesSection(_selectedProjectId!),
          ),
        ],
      ),
    );
  }

  Widget _buildStagesSection(String projectId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('stages')
          .stream(primaryKey: ['id'])
          .eq('project_id', projectId)
          .order('created_at', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        final stages = snapshot.data ?? [];

        final filteredStages = stages.where((s) {
          final name = (s['name'] as String?)?.toLowerCase() ?? '';
          return name.contains(_searchQuery);
        }).toList();

        if (filteredStages.isEmpty) {
          return const Center(child: Text('В проекте пока нет этапов'));
        }

        final now = DateTime.now();

        return FutureBuilder<double>(
          future: _calculateOverallProgress(projectId),
          builder: (context, overallSnap) {
            final overall = overallSnap.data ?? 0.0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Общий прогресс проекта',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: overall,
                              minHeight: 20,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(
                                overall >= 0.9
                                    ? Colors.green.shade600
                                    : overall >= 0.6
                                    ? Colors.blue.shade600
                                    : Colors.orange.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(overall * 100).toInt()}% завершено',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: filteredStages.length,
                    itemBuilder: (context, index) {
                      final stage = filteredStages[index];
                      final name = stage['name'] as String? ?? 'Без названия';
                      final description = stage['description'] as String?;
                      final statusStr =
                          (stage['status'] as String?)?.toLowerCase() ??
                          'planned';
                      final start = stage['start_date'] as String?;
                      final end = stage['end_date'] as String?;

                      final endDate = end != null
                          ? DateTime.tryParse(end)
                          : null;
                      final isOverdue =
                          endDate != null &&
                          endDate.isBefore(now) &&
                          statusStr != 'completed';

                      return FutureBuilder<double>(
                        future: _calculateStageProgress(stage['id'] as String),
                        builder: (context, stageSnap) {
                          final progress = stageSnap.data ?? 0.0;

                          return TimelineTile(
                            alignment: TimelineAlign.manual,
                            lineXY: 0.12,
                            isFirst: index == 0,
                            isLast: index == filteredStages.length - 1,
                            indicatorStyle: IndicatorStyle(
                              width: 56,
                              height: 56,
                              indicatorXY: 0.5,
                              drawGap: true,
                              indicator: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getStageStatusColor(statusStr),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${(progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            beforeLineStyle: LineStyle(
                              color: _getStageStatusColor(
                                statusStr,
                              ).withOpacity(0.5),
                              thickness: 5,
                            ),
                            afterLineStyle: LineStyle(
                              color: _getStageStatusColor(
                                statusStr,
                              ).withOpacity(0.5),
                              thickness: 5,
                            ),
                            endChild: Card(
                              margin: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: isOverdue ? Colors.red.shade50 : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 14,
                                          color: _getStageStatusColor(
                                            statusStr,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (description != null &&
                                        description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        description,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${start ?? '—'}  —  ${end ?? '—'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                        if (isOverdue)
                                          Text(
                                            'Просрочен',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 10,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        valueColor: AlwaysStoppedAnimation(
                                          progress >= 0.9
                                              ? Colors.green.shade600
                                              : progress >= 0.6
                                              ? Colors.blue.shade600
                                              : Colors.orange.shade600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${(progress * 100).toInt()}% завершено',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<double> _calculateOverallProgress(String projectId) async {
    try {
      final project = await _supabase
          .from('projects')
          .select('manual_progress')
          .eq('id', projectId)
          .maybeSingle();

      final manual = (project?['manual_progress'] as num?)?.toDouble() ?? 0.0;
      if (manual > 0) return (manual / 100).clamp(0.0, 1.0);

      final stages = await _supabase
          .from('stages')
          .select('id')
          .eq('project_id', projectId);
      if (stages.isEmpty) return 0.0;

      final stageIds = stages.map((s) => s['id'] as String).toList();

      final works = await _supabase
          .from('works')
          .select('progress')
          .inFilter('stage_id', stageIds);
      if (works.isEmpty) return 0.0;

      final sum = works.fold<double>(
        0.0,
        (prev, w) => prev + ((w['progress'] as num?)?.toDouble() ?? 0.0),
      );

      return (sum / works.length / 100).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Ошибка расчёта общего прогресса: $e');
      return 0.0;
    }
  }

  Future<double> _calculateStageProgress(String stageId) async {
    try {
      final works = await _supabase
          .from('works')
          .select('progress')
          .eq('stage_id', stageId);
      if (works.isEmpty) return 0.0;

      final sum = works.fold<double>(
        0.0,
        (prev, w) => prev + ((w['progress'] as num?)?.toDouble() ?? 0.0),
      );

      return (sum / works.length / 100).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Ошибка расчёта прогресса этапа: $e');
      return 0.0;
    }
  }

  Color _getStageStatusColor(String statusStr) {
    final status = statusStr.toLowerCase();
    return switch (status) {
      'planned' => Colors.grey.shade600,
      'in_progress' => Colors.blue.shade600,
      'paused' => Colors.orange.shade700,
      'completed' => Colors.green.shade700,
      _ => Colors.grey.shade500,
    };
  }

  String _formatRole(String role) {
    return switch (role.toLowerCase()) {
      'leader' => 'Руководитель',
      'admin' => 'Администратор',
      'client' => 'Клиент',
      'worker' => 'Исполнитель',
      _ => 'Участник',
    };
  }
}
