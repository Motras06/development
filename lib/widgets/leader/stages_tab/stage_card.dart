import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '/models/enums.dart';
import 'create_stage_dialog.dart';

final supabase = Supabase.instance.client;

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

  StageStatus get status => StageStatus.values.firstWhere(
    (e) => e.name == (widget.stage['status'] as String? ?? 'planned'),
    orElse: () => StageStatus.planned,
  );

  @override
  void initState() {
    super.initState();
    _loadDocumentsAndComments();
  }

  Future<void> _loadDocumentsAndComments() async {
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
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки документов/комментариев: $e');
    }
  }

  Future<void> _addComment() async {
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
                await supabase.from('comments').insert({
                  'entity_type': 'stage',
                  'entity_id': widget.stage['id'],
                  'user_id': supabase.auth.currentUser?.id,
                  'text': text,
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Комментарий добавлен')),
                  );
                  _loadDocumentsAndComments();
                  widget.onRefresh?.call();
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

  Future<void> _editStage() async {
    CreateStageDialog.show(
      context,
      projectId: widget.stage['project_id'],
      stageToEdit: widget.stage,
      onSuccess: widget.onRefresh,
    );
  }

  Future<void> _deleteStage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить этап?'),
        content: const Text(
          'Все связанные данные (документы, комментарии) будут удалены без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('stages').delete().eq('id', widget.stage['id']);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Этап удалён')));
        widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
      }
    }
  }

  Future<void> _openDocument(Map<String, dynamic> doc) async {
    final url = doc['file_url'] as String?;
    if (url == null) return;

    try {
      final dio = Dio();
      final fileName =
          doc['name'] ?? 'file_${DateTime.now().millisecondsSinceEpoch}';

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Не удалось получить директорию Downloads');
      }

      final savePath = '${directory.path}/$fileName';

      await dio.download(url, savePath);

      final openResult = await OpenFilex.open(savePath);

      if (openResult.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть файл: ${openResult.message}'),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл скачан в Downloads: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка скачивания: $e')));
      }
      debugPrint('Ошибка при скачивании файла: $e');
    }
  }

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

  Widget _buildResources(String title, List<dynamic>? items) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ...items.map(
          (r) => Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              '• ${r['name']} ${r['quantity'] != null ? ' — ${r['quantity']} ${r['unit'] ?? ''}' : ''}',
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Color _statusColor(StageStatus s) => switch (s) {
    StageStatus.planned => Colors.grey.shade600,
    StageStatus.in_progress => Colors.blue,
    StageStatus.paused => Colors.orange,
    StageStatus.completed => Colors.green.shade700,
  };

  @override
  Widget build(BuildContext context) {
    final name = widget.stage['name'] as String? ?? 'Без названия';
    final desc = widget.stage['description'] as String?;
    final start = widget.stage['start_date'] as String?;
    final end = widget.stage['end_date'] as String?;
    final matRes = widget.stage['material_resources'] as List<dynamic>?;
    final nonMatRes = widget.stage['non_material_resources'] as List<dynamic>?;

    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 24,
          child: Text(
            status.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        subtitle: Text(
          '${start ?? '—'} → ${end ?? '—'}',
          style: TextStyle(color: Colors.grey[700]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: _editStage,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteStage,
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (desc != null && desc.isNotEmpty) ...[
            Text(desc, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 16),
          ],

          _buildResources('Материалы', matRes),
          _buildResources('Нематериальные', nonMatRes),

          const Divider(height: 28),

          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text('Документы (${_documents.length})'),
          ),
          if (_documents.isNotEmpty)
            ..._documents.map(
              (doc) => ListTile(
                dense: true,
                leading: Icon(_getFileIcon(doc['name'] as String?)),
                title: Text(
                  doc['name'] ?? 'Без имени',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatDate(doc['uploaded_at'] as String?),
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => _openDocument(doc),
              ),
            ),

          const Divider(height: 28),

          ListTile(
            leading: const Icon(Icons.comment_outlined),
            title: Text('Комментарии (${_comments.length})'),
            trailing: IconButton(
              icon: const Icon(Icons.add_comment),
              onPressed: _addComment,
            ),
          ),
          if (_comments.isNotEmpty)
            ..._comments
                .take(5)
                .map(
                  (c) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(c['users']?['full_name']?[0] ?? '?'),
                    ),
                    title: Text(
                      c['text'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${c['users']?['full_name'] ?? 'Аноним'} • ${_formatDate(c['created_at'] as String?)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
          if (_comments.length > 5)
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Полный список комментариев — в разработке'),
                ),
              ),
              child: const Text('Показать все'),
            ),
        ],
      ),
    );
  }
}
