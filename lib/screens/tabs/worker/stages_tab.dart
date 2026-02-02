import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '/models/enums.dart';

final supabase = Supabase.instance.client;

class StagesTab extends StatefulWidget {
  const StagesTab({super.key});

  @override
  State<StagesTab> createState() => _StagesTabState();
}

class _StagesTabState extends State<StagesTab> {
  final userId = supabase.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (userId == null) return;

    try {
      final participantData = await supabase
          .from('project_participants')
          .select(
            'project_id, projects(id, name, description, start_date, end_date, status)',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Заголовок + выбор проекта
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.timeline_rounded, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Этапы проектов',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dropdown проектов
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButton<Map<String, dynamic>?>(
                    isExpanded: true,
                    value: _selectedProject,
                    hint: Text(
                      'Выберите проект',
                      style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    underline: const SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
                    items: _projects.map((project) {
                      return DropdownMenuItem(
                        value: project,
                        child: Text(
                          project['name'] as String,
                          style: theme.textTheme.bodyLarge,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedProject = value),
                  ),
                ),
              ),
            ),

            // Поиск
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  labelText: 'Поиск по названию этапа',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Список этапов
            Expanded(
              child: _selectedProject == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 80, color: colorScheme.primary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'Выберите проект',
                            style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Чтобы увидеть этапы',
                            style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: supabase
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
                          final name = (s['name'] as String?)?.toLowerCase() ?? '';
                          return name.contains(_searchQuery);
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 80, color: colorScheme.primary.withOpacity(0.4)),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет этапов',
                                  style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final stage = filtered[index];
                            return AnimatedOpacity(
                              opacity: 1.0,
                              duration: Duration(milliseconds: 300 + index * 100),
                              child: StageCard(
                                stage: stage,
                                onRefresh: () => setState(() {}),
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
    );
  }
}

// Красивая карточка этапа
class StageCard extends StatefulWidget {
  final Map<String, dynamic> stage;
  final VoidCallback? onRefresh;

  const StageCard({super.key, required this.stage, this.onRefresh});

  @override
  State<StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<StageCard> {
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  StageStatus get status => StageStatus.values.firstWhere(
        (e) => e.name == (widget.stage['status'] as String? ?? 'planned'),
        orElse: () => StageStatus.planned,
      );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final docsRes = await supabase
          .from('stage_documents')
          .select()
          .eq('stage_id', widget.stage['id'])
          .order('uploaded_at', ascending: false);

      final commRes = await supabase
          .from('comments')
          .select('*, users!user_id(full_name)')
          .eq('entity_type', 'stage')
          .eq('entity_id', widget.stage['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _documents = List<Map<String, dynamic>>.from(docsRes);
          _comments = List<Map<String, dynamic>>.from(commRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый комментарий'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(hintText: 'Что вы думаете об этом этапе?'),
          maxLines: 5,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              final text = commentController.text.trim();
              if (text.isEmpty) return;

              try {
                await supabase.from('comments').insert({
                  'entity_type': 'stage',
                  'entity_id': widget.stage['id'],
                  'user_id': supabase.auth.currentUser?.id,
                  'text': text,
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Комментарий добавлен'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                  _loadData();
                  widget.onRefresh?.call();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(Map<String, dynamic> doc) async {
    final url = doc['file_url'] as String?;
    if (url == null) return;

    try {
      final dio = Dio();
      final fileName = doc['name'] ?? 'file_${DateTime.now().millisecondsSinceEpoch}';

      final directory = await getDownloadsDirectory();
      if (directory == null) throw Exception('Не удалось получить директорию Downloads');

      final savePath = '${directory.path}/$fileName';

      await dio.download(url, savePath);

      final openResult = await OpenFilex.open(savePath);

      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть: ${openResult.message}')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл скачан в Downloads: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка скачивания: $e')),
        );
      }
    }
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file_rounded;
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'doc' || 'docx' => Icons.description_rounded,
      'xls' || 'xlsx' => Icons.table_chart_rounded,
      'png' || 'jpg' || 'jpeg' || 'gif' => Icons.image_rounded,
      'zip' || 'rar' => Icons.archive_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  Widget _buildResources(String title, List<dynamic>? items) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        ...items.map(
          (r) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${r['name']} ${r['quantity'] != null ? ' — ${r['quantity']} ${r['unit'] ?? ''}' : ''}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Color _statusColor(StageStatus s) => switch (s) {
        StageStatus.planned => Colors.grey.shade600,
        StageStatus.in_progress => Colors.blue.shade600,
        StageStatus.paused => Colors.orange.shade700,
        StageStatus.completed => Colors.green.shade700,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = widget.stage['name'] as String? ?? 'Без названия';
    final desc = widget.stage['description'] as String?;
    final start = widget.stage['start_date'] as String?;
    final end = widget.stage['end_date'] as String?;
    final matRes = widget.stage['material_resources'] as List<dynamic>?;
    final nonMatRes = widget.stage['non_material_resources'] as List<dynamic>?;

    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 28,
          child: Text(
            status.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${start ?? '—'} → ${end ?? '—'}',
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: colorScheme.primary,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc != null && desc.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                desc,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],

          _buildResources('Материалы', matRes),
          _buildResources('Нематериальные', nonMatRes),

          const Divider(height: 32, thickness: 1),

          // Документы
          ListTile(
            leading: Icon(Icons.folder_rounded, color: colorScheme.primary),
            title: Text(
              'Документы (${_documents.length})',
              style: theme.textTheme.titleMedium,
            ),
            trailing: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          if (_documents.isNotEmpty)
            ..._documents.map(
              (doc) => ListTile(
                dense: true,
                leading: Icon(_getFileIcon(doc['name'] as String?), color: colorScheme.primary),
                title: Text(
                  doc['name'] ?? 'Без имени',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatDate(doc['uploaded_at'] as String?),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Icon(Icons.download_rounded, size: 20, color: colorScheme.primary),
                onTap: () => _openDocument(doc),
              ),
            )
          else if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Документов пока нет',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),

          const Divider(height: 32, thickness: 1),

          // Комментарии
          ListTile(
            leading: Icon(Icons.comment_rounded, color: colorScheme.primary),
            title: Text(
              'Комментарии (${_comments.length})',
              style: theme.textTheme.titleMedium,
            ),
            trailing: IconButton(
              icon: Icon(Icons.add_comment_rounded, color: colorScheme.primary),
              onPressed: _addComment,
            ),
          ),
          if (_comments.isNotEmpty)
            ..._comments.take(5).map(
                  (c) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        c['users']?['full_name']?[0] ?? '?',
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                    title: Text(
                      c['text'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${c['users']?['full_name'] ?? 'Аноним'} • ${_formatDate(c['created_at'] as String?)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
          if (_comments.length > 5)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Полный список — в разработке')),
                    );
                  },
                  child: const Text('Показать все комментарии'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}