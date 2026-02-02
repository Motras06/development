import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class DocumentsTab extends StatefulWidget {
  const DocumentsTab({super.key});

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  String? _selectedProjectId;
  String? _selectedStageId;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (userId == null) {
      return const Center(child: Text('Не авторизован'));
    }

    return Scaffold(
      body: Column(
        children: [
          // Шапка: выбор проекта + этап + поиск
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Выбор проекта
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase
                      .from('project_participants')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', userId!)
                      .order('joined_at', ascending: false),
                  builder: (context, participantSnap) {
                    if (participantSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
                    }

                    final participants = participantSnap.data ?? [];
                    if (participants.isEmpty) {
                      return const SizedBox(height: 56, child: Center(child: Text('Нет проектов')));
                    }

                    final projectIds = participants.map((p) => p['project_id'] as String).toList();

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _supabase
                          .from('projects')
                          .stream(primaryKey: ['id'])
                          .inFilter('id', projectIds)
                          .order('created_at', ascending: false),
                      builder: (context, projectSnap) {
                        if (projectSnap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
                        }

                        final projects = projectSnap.data ?? [];
                        if (projects.isEmpty) {
                          return const SizedBox(height: 56, child: Center(child: Text('Проекты не найдены')));
                        }

                        // Автовыбор первого проекта
                        if (_selectedProjectId == null && projects.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _selectedProjectId = projects.first['id'] as String);
                          });
                        }

                        final selectedProject = projects.firstWhere(
                          (p) => p['id'] == _selectedProjectId,
                          orElse: () => projects.isNotEmpty ? projects.first : <String, dynamic>{},
                        );

                        return DropdownButton<Map<String, dynamic>>(
                          value: selectedProject.isNotEmpty ? selectedProject : null,
                          isExpanded: true,
                          hint: const Text('Выберите проект'),
                          underline: const SizedBox(),
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
                          items: projects.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p['name'] as String? ?? 'Без названия'),
                          )).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProjectId = value['id'] as String;
                                _selectedStageId = null; // сбрасываем этап
                              });
                            }
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 2. Выбор этапа (если проект выбран)
                if (_selectedProjectId != null)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _supabase
                        .from('stages')
                        .select('id, name')
                        .eq('project_id', _selectedProjectId!)
                        .order('created_at', ascending: true),
                    builder: (context, stageSnap) {
                      if (stageSnap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
                      }

                      final stages = stageSnap.data ?? [];
                      if (stages.isEmpty) {
                        return const SizedBox(height: 56, child: Center(child: Text('В проекте нет этапов')));
                      }

                      // Автовыбор первого этапа
                      if (_selectedStageId == null && stages.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selectedStageId = stages.first['id'] as String);
                        });
                      }

                      final selectedStage = stages.firstWhere(
                        (s) => s['id'] == _selectedStageId,
                        orElse: () => stages.isNotEmpty ? stages.first : <String, dynamic>{},
                      );

                      return DropdownButton<Map<String, dynamic>>(
                        value: selectedStage.isNotEmpty ? selectedStage : null,
                        isExpanded: true,
                        hint: const Text('Выберите этап'),
                        underline: const SizedBox(),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
                        items: stages.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s['name'] as String? ?? 'Без названия'),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedStageId = value['id'] as String);
                          }
                        },
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // 3. Поиск
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    labelText: 'Поиск по названию документа',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),

          // Список документов (для выбранного этапа)
          Expanded(
            child: _selectedProjectId == null
                ? _emptyState('Выберите проект')
                : _selectedStageId == null
                    ? _emptyState('Выберите этап')
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _supabase
                            .from('stage_documents')
                            .stream(primaryKey: ['id'])
                            .eq('stage_id', _selectedStageId!)
                            .order('uploaded_at', ascending: false),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: colorScheme.error)),
                            );
                          }

                          final docs = snapshot.data ?? [];

                          final filtered = docs.where((doc) {
                            final name = (doc['name'] as String?)?.toLowerCase() ?? '';
                            return name.contains(_searchQuery);
                          }).toList();

                          if (filtered.isEmpty) {
                            return _emptyState(
                              _searchQuery.isNotEmpty
                                  ? 'По вашему запросу ничего не найдено'
                                  : 'На этом этапе пока нет документов',
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final name = doc['name'] as String? ?? 'Без названия';
                              final description = doc['description'] as String?;
                              final fileUrl = doc['file_url'] as String?;
                              final uploadedAt = doc['uploaded_at'] as String?;
                              final uploadedBy = doc['uploaded_by'] as String?;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: colorScheme.primaryContainer,
                                    child: Icon(
                                      Icons.description_rounded,
                                      color: colorScheme.onPrimaryContainer,
                                      size: 28,
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (description != null && description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      if (uploadedAt != null)
                                        Text(
                                          'Загружен: ${_formatDate(uploadedAt)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      if (uploadedBy != null)
                                        FutureBuilder<String>(
                                          future: _supabase
                                              .from('users')
                                              .select('full_name')
                                              .eq('id', uploadedBy)
                                              .maybeSingle()
                                              .then((data) => data?['full_name'] as String? ?? 'Неизвестно'),
                                          builder: (context, snap) {
                                            return Text(
                                              'Автор: ${snap.data ?? 'Загрузка...'}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.download_rounded, color: colorScheme.primary),
                                    tooltip: 'Скачать и открыть',
                                    onPressed: fileUrl != null
                                        ? () => _downloadAndOpenDocument(fileUrl, name)
                                        : null,
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
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет документов',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpenDocument(String url, String fileName) async {
    try {
      final dio = Dio();
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/$fileName';

      await dio.download(url, savePath);

      final result = await OpenFilex.open(savePath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть: ${result.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка скачивания/открытия: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return '—';
    }
  }
}