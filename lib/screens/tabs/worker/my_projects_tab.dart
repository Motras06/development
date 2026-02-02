import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class MyProjectsTab extends StatefulWidget {
  const MyProjectsTab({super.key});

  @override
  State<MyProjectsTab> createState() => _MyProjectsTabState();
}

class _MyProjectsTabState extends State<MyProjectsTab>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  String _searchQuery = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (userId == null) {
      return const Center(child: Text('Ошибка авторизации'));
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.06),
              colorScheme.surface,
              colorScheme.surfaceTint.withOpacity(0.04),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мои проекты',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Поиск по названию проекта...',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: colorScheme.primary,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('project_participants')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', userId!)
                      .order('joined_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Ошибка: ${snapshot.error}'));
                    }

                    final participants = snapshot.data ?? [];

                    if (participants.isEmpty) {
                      return _buildEmptyState(colorScheme);
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
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (projectSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'Ошибка загрузки: ${projectSnapshot.error}',
                            ),
                          );
                        }

                        var projects = projectSnapshot.data ?? [];

                        if (_searchQuery.isNotEmpty) {
                          projects = projects.where((p) {
                            final name =
                                (p['name'] as String?)?.toLowerCase() ?? '';
                            return name.contains(_searchQuery);
                          }).toList();
                        }

                        if (projects.isEmpty) {
                          return Center(
                            child: Text(
                              'Проекты не найдены',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                final project = projects[index];
                                final name =
                                    project['name'] as String? ??
                                    'Без названия';
                                final description =
                                    project['description'] as String?;
                                final statusStr =
                                    project['status'] as String? ?? 'active';
                                final startDate =
                                    project['start_date'] as String?;
                                final endDate = project['end_date'] as String?;
                                final manualProgress =
                                    (project['manual_progress'] as num?)
                                        ?.toDouble() ??
                                    0.0;

                                final progress = manualProgress.clamp(
                                  0.0,
                                  100.0,
                                );
                                final progressColor = progress < 30
                                    ? Colors.red.shade600
                                    : progress < 70
                                    ? Colors.orange.shade600
                                    : Colors.green.shade600;

                                final participant = participants.firstWhere(
                                  (p) => p['project_id'] == project['id'],
                                  orElse: () => {'role': 'worker'},
                                );
                                final roleStr = participant['role'] as String;
                                final role = ParticipantRole.values.firstWhere(
                                  (r) => r.name == roleStr,
                                  orElse: () => ParticipantRole.worker,
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildGlassmorphicCard(
                                    context,
                                    name: name,
                                    description: description,
                                    progress: progress,
                                    progressColor: progressColor,
                                    statusStr: statusStr,
                                    role: role,
                                    startDate: startDate,
                                    endDate: endDate,
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Открыть проект: $name',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 96,
            color: colorScheme.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 24),
          Text(
            'Нет проектов',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Вы пока не участвуете ни в одном проекте.\nПрисоединяйтесь к проекту или создайте свой!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicCard(
    BuildContext context, {
    required String name,
    String? description,
    required double progress,
    required Color progressColor,
    required String statusStr,
    required ParticipantRole role,
    String? startDate,
    String? endDate,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getRoleIcon(role),
                          color: _getRoleColor(role),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (description != null && description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _getStatusColor(statusStr),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _projectStatusName(statusStr),
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: progressColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${progress.toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: progressColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 12,
                      backgroundColor: colorScheme.surfaceContainerHighest
                          .withOpacity(0.6),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),

                  if (startDate != null || endDate != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Сроки: ${startDate ?? '—'} — ${endDate ?? '—'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(ParticipantRole role) {
    return switch (role) {
      ParticipantRole.leader => Colors.blue.shade600,
      ParticipantRole.worker => Colors.green.shade600,
      ParticipantRole.client => Colors.orange.shade600,
      ParticipantRole.admin => Colors.purple.shade600,
    };
  }

  IconData _getRoleIcon(ParticipantRole role) {
    return switch (role) {
      ParticipantRole.leader => Icons.star_rounded,
      ParticipantRole.worker => Icons.construction_rounded,
      ParticipantRole.client => Icons.person_rounded,
      ParticipantRole.admin => Icons.security_rounded,
    };
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'active' => Colors.green.shade600,
      'paused' => Colors.orange.shade600,
      'archived' => Colors.grey.shade600,
      'completed' => Colors.blue.shade600,
      _ => Colors.grey.shade600,
    };
  }

  String _projectStatusName(String status) {
    return switch (status) {
      'active' => 'Активный',
      'paused' => 'На паузе',
      'archived' => 'В архиве',
      'completed' => 'Завершён',
      _ => status,
    };
  }
}
