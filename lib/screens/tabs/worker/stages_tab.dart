import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/enums.dart';

class StagesTab extends StatefulWidget {
  const StagesTab({super.key});

  @override
  State<StagesTab> createState() => _StagesTabState();
}

class _StagesTabState extends State<StagesTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  String _searchQuery = '';

  // Кэш прогресса этапов
  final Map<String, double> _stageProgressCache = {};

  // Кэш документов по project_id
  final Map<String, List<Map<String, dynamic>>> _documentsCache = {};

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (userId == null) return;

    try {
      final participantData = await _supabase
          .from('project_participants')
          .select(
            'project_id, projects(id, name, description, start_date, end_date, status, manual_progress)',
          )
          .eq('user_id', userId!);

      final myProjects = participantData
          .map((e) => e['projects'] as Map<String, dynamic>)
          .toList();

      setState(() {
        _projects = myProjects;
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  Future<void> _addComment(String stageId) async {
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Комментарий к этапу'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(hintText: 'Ваш комментарий...'),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final text = commentController.text.trim();
              if (text.isEmpty) return;

              try {
                await _supabase.from('comments').insert({
                  'entity_type': 'stage',
                  'entity_id': stageId,
                  'user_id': userId,
                  'text': text,
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Комментарий добавлен')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                }
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  Future<double> _calculateStageProgress(String stageId) async {
    if (_stageProgressCache.containsKey(stageId))
      return _stageProgressCache[stageId]!;

    try {
      final works = await _supabase
          .from('works')
          .select('status')
          .eq('stage_id', stageId);
      if (works.isEmpty) return 0.0;

      final completed = works
          .where((w) => w['status'] == WorkStatus.done.name)
          .length;
      final progress = completed / works.length;

      _stageProgressCache[stageId] = progress;
      return progress;
    } catch (e) {
      debugPrint('Ошибка расчёта прогресса: $e');
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> _loadDocuments(String projectId) async {
    if (_documentsCache.containsKey(projectId))
      return _documentsCache[projectId]!;

    try {
      final docs = await _supabase
          .from('technical_documents')
          .select()
          .eq('project_id', projectId)
          .order('uploaded_at', ascending: false);

      _documentsCache[projectId] = List<Map<String, dynamic>>.from(docs);
      return _documentsCache[projectId]!;
    } catch (e) {
      debugPrint('Ошибка загрузки документов: $e');
      return [];
    }
  }

  // Открытие/скачивание файла — используется в карточке
  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть файл')),
        );
      }
    }
  }

  // Иконка файла — используется в карточке
  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file;
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'doc' || 'docx' => Icons.description,
      'xls' || 'xlsx' => Icons.table_chart,
      'png' || 'jpg' || 'jpeg' || 'gif' => Icons.image,
      'zip' || 'rar' => Icons.archive,
      _ => Icons.insert_drive_file,
    };
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  Color _getStatusColor(StageStatus status) {
    return switch (status) {
      StageStatus.planned => Colors.grey,
      StageStatus.in_progress => Colors.blue,
      StageStatus.paused => Colors.orange,
      StageStatus.completed => Colors.green,
    };
  }

  Widget _buildResourcesSection(String title, List<dynamic> resources) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...resources.map((res) {
            final name = res['name'] as String? ?? 'Без названия';
            final quantity = res['quantity'] as num?;
            final unit = res['unit'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                '• $name${quantity != null ? " — $quantity $unit" : ""}',
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Выбор проекта
          if (_projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButton<Map<String, dynamic>?>(
                isExpanded: true,
                hint: const Text('Выберите проект'),
                value: _selectedProject,
                items: _projects.map((project) {
                  return DropdownMenuItem(
                    value: project,
                    child: Text(project['name'] as String),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedProject = value),
              ),
            ),

          // Поиск
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                labelText: 'Поиск по названию этапа',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Список этапов
          Expanded(
            child: _selectedProject == null
                ? const Center(
                    child: Text('Выберите проект для просмотра этапов'),
                  )
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('stages')
                        .stream(primaryKey: ['id'])
                        .eq('project_id', _selectedProject!['id'])
                        .order('created_at', ascending: true),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Ошибка: ${snapshot.error}'));
                      }

                      final stages = snapshot.data ?? [];

                      final filtered = stages.where((s) {
                        final name =
                            (s['name'] as String?)?.toLowerCase() ?? '';
                        return name.contains(_searchQuery);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('Нет этапов или ничего не найдено'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final stage = filtered[index];
                          final name =
                              stage['name'] as String? ?? 'Без названия';
                          final description = stage['description'] as String?;
                          final statusStr =
                              stage['status'] as String? ?? 'planned';
                          final start = stage['start_date'] as String?;
                          final end = stage['end_date'] as String?;
                          final material =
                              stage['material_resources'] as List<dynamic>? ??
                              [];
                          final nonMaterial =
                              stage['non_material_resources']
                                  as List<dynamic>? ??
                              [];

                          final status = StageStatus.values.firstWhere(
                            (e) => e.name == statusStr,
                            orElse: () => StageStatus.planned,
                          );

                          return FutureBuilder<double>(
                            future: _calculateStageProgress(
                              stage['id'] as String,
                            ),
                            builder: (context, progressSnapshot) {
                              final progress = progressSnapshot.data ?? 0.0;
                              final progressColor = progress < 0.3
                                  ? Colors.red
                                  : progress < 0.7
                                  ? Colors.orange
                                  : Colors.green;

                              return FutureBuilder<List<Map<String, dynamic>>>(
                                future: _loadDocuments(
                                  _selectedProject!['id'] as String,
                                ),
                                builder: (context, docsSnapshot) {
                                  final documents = docsSnapshot.data ?? [];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ExpansionTile(
                                      leading: CircleAvatar(
                                        backgroundColor: _getStatusColor(
                                          status,
                                        ),
                                        radius: 24,
                                        child: Text(
                                          status.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${start ?? 'Не указана'} — ${end ?? 'Не указана'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('${(progress * 100).toInt()}%'),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 5,
                                              backgroundColor: Colors.grey[300],
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    progressColor,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      children: [
                                        if (description != null &&
                                            description.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              description,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ),

                                        if (material.isNotEmpty)
                                          _buildResourcesSection(
                                            'Материальные ресурсы',
                                            material,
                                          ),

                                        if (nonMaterial.isNotEmpty)
                                          _buildResourcesSection(
                                            'Нематериальные ресурсы',
                                            nonMaterial,
                                          ),

                                        // Вот здесь настоящие документы — кликабельные
                                        if (documents.isNotEmpty) ...[
                                          const Divider(height: 24),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.folder_outlined,
                                                  color: Colors.blue,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Документы (${documents.length})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ...documents.map((doc) {
                                            final fileName =
                                                doc['name'] as String? ??
                                                'Без имени';
                                            final uploadedAt =
                                                doc['uploaded_at'] as String?;
                                            final url =
                                                doc['file_url'] as String?;

                                            return ListTile(
                                              dense: true,
                                              leading: Icon(
                                                _getFileIcon(fileName),
                                              ),
                                              title: Text(
                                                fileName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: uploadedAt != null
                                                  ? Text(
                                                      'Загружено: ${_formatDate(uploadedAt)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    )
                                                  : null,
                                              trailing: const Icon(
                                                Icons.download,
                                                size: 20,
                                                color: Colors.blue,
                                              ),
                                              onTap: url != null
                                                  ? () => _openDocument(url)
                                                  : null,
                                            );
                                          }),
                                        ],

                                        const SizedBox(height: 12),

                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () => _addComment(
                                              stage['id'] as String,
                                            ),
                                            icon: const Icon(
                                              Icons.comment,
                                              size: 20,
                                            ),
                                            label: const Text(
                                              'Оставить комментарий',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              foregroundColor:
                                                  colorScheme.primary,
                                              elevation: 0,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
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
}
