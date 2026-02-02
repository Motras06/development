import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:developer' as dev;

class DatabaseExplorer extends StatefulWidget {
  final String tableName;

  const DatabaseExplorer({super.key, required this.tableName});

  @override
  State<DatabaseExplorer> createState() => _DatabaseExplorerState();
}

class _DatabaseExplorerState extends State<DatabaseExplorer> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _errorMessage;

  static const Map<String, String> _sortColumns = {
    'stage_documents': 'uploaded_at',
    'project_participants': 'joined_at',
    'messages': 'created_at',
  };

  @override
  void initState() {
    super.initState();
    _loadData();

    supabase
        .channel('admin_changes_${widget.tableName}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: widget.tableName,
          callback: (payload) {
            dev.log('Изменение в таблице ${widget.tableName}');
            _loadData();
          },
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });

      final sortColumn = _sortColumns[widget.tableName] ?? 'created_at';

      var query = supabase.from(widget.tableName);
      String selectFields = '*';
      if (widget.tableName == 'stage_documents') {
        selectFields = '*, uploaded_by_user:uploaded_by(full_name)';
      }

      final data = await query
          .select(selectFields)
          .order(sortColumn, ascending: false)
          .limit(200);

      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e, stack) {
      dev.log('Ошибка загрузки: $e\n$stack');
      setState(() {
        _errorMessage = _beautifyError(e);
        _loading = false;
      });
    }
  }

  String _beautifyError(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('column') && errorStr.contains('does not exist')) {
      return 'Ошибка схемы: в таблице нет ожидаемой колонки (возможно created_at / uploaded_at)';
    }
    if (errorStr.contains('permission denied')) {
      return 'Нет прав доступа к таблице. Проверьте RLS политики в Supabase';
    }
    if (errorStr.contains('relationship') || errorStr.contains('foreign key')) {
      return 'Проблема с join (uploaded_by_user). Проверьте RLS для users';
    }
    return 'Ошибка: $errorStr';
  }

  Future<void> _delete(String? id) async {
    if (id == null || id.isEmpty) return;

    try {
      await supabase.from(widget.tableName).delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Запись удалена')));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось удалить: ${_beautifyError(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditBottomSheet({Map<String, dynamic>? initial}) {
    final isNew = initial == null;
    final tempData = Map<String, dynamic>.from(initial ?? {});

    Set<String> allKeys = {};
    if (_rows.isNotEmpty) {
      allKeys = _rows.first.keys.toSet();
    }

    final editableFields =
        allKeys
            .where(
              (k) =>
                  k != 'id' &&
                  !k.contains('created_at') &&
                  !k.contains('updated_at') &&
                  !k.contains('joined_at') &&
                  !k.contains('uploaded_at') &&
                  !k.contains('uploaded_by_user'), 
            )
            .toList()
          ..sort();

    if (editableFields.isEmpty && !isNew) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет редактируемых полей в этой записи')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.50,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(isNew ? 'Создать запись' : 'Редактировать'),
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      try {
                        if (isNew) {
                          await supabase
                              .from(widget.tableName)
                              .insert(tempData);
                        } else {
                          await supabase
                              .from(widget.tableName)
                              .update(tempData)
                              .eq('id', initial['id']);
                        }

                        if (!mounted) return;
                        Navigator.pop(context);
                        await _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isNew ? 'Запись создана' : 'Изменения сохранены',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Ошибка сохранения: ${_beautifyError(e)}',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text(isNew ? 'Создать' : 'Сохранить'),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (editableFields.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'В этой таблице нет полей, доступных для редактирования в текущей реализации',
                          style: TextStyle(color: Colors.orange),
                        ),
                      )
                    else
                      ...editableFields.map((field) {
                        final initialValue = tempData[field]?.toString() ?? '';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: TextField(
                            controller: TextEditingController(
                              text: initialValue,
                            ),
                            decoration: InputDecoration(
                              labelText: _formatFieldName(field),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                            ),
                            maxLines: _needsMultiline(field) ? 4 : 1,
                            onChanged: (v) =>
                                tempData[field] = v.isEmpty ? null : v,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  bool _needsMultiline(String field) {
    return field.contains('description') ||
        field.contains('text') ||
        field.contains('comment') ||
        field.contains('note') ||
        field.length > 25;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Не удалось загрузить данные',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              )
            : _rows.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 88,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 24),
                    Text('Пока нет записей', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(
                      'Нажмите кнопку "+" чтобы добавить первую запись',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  final titleField = _guessTitleField(row);
                  final subtitle = _guessSubtitle(row);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showEditBottomSheet(initial: row),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row[titleField]?.toString() ??
                                        '(без названия)',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'ID: ${(row['id']?.toString() ?? '').substring(0, row['id'] != null ? 8 : 0)}...',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                if (widget.tableName == 'stage_documents' &&
                                    row['file_url'] != null)
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    onPressed: () => _openOrDownloadDocument(
                                      row,
                                      open: true,
                                    ),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: () =>
                                      _confirmDelete(row['id'] as String?),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditBottomSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
    );
  }

  Future<void> _openOrDownloadDocument(
    Map<String, dynamic> doc, {
    bool open = true,
  }) async {
    final url = doc['file_url'] as String?;
    final name = doc['name'] as String? ?? 'document';

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нет ссылки на файл')));
      return;
    }

    try {
      final dio = Dio();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$name';

      await dio.download(url, path);

      if (open) {
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть: ${result.message}')),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Файл сохранён')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmDelete(String? id) {
    if (id == null || id.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Удалить запись?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete(id);
            },
            child: Text(
              'Удалить',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  String _guessTitleField(Map<String, dynamic> row) {
    const priority = [
      'name',
      'title',
      'full_name',
      'email',
      'description',
      'text',
      'comment',
    ];

    for (var field in priority) {
      if (row.containsKey(field)) return field;
    }

    return row.keys.firstWhere((k) => k != 'id', orElse: () => 'id');
  }

  String _guessSubtitle(Map<String, dynamic> row) {
    final parts = <String>[];

    for (var key in row.keys) {
      final value = row[key]?.toString();
      if (value == null || value.isEmpty) continue;

      if (key.contains('status') ||
          key.contains('role') ||
          key.contains('type') ||
          key.contains('progress') ||
          key.contains('date') ||
          key.contains('phone') ||
          key.contains('uploaded_at')) {
        parts.add(value);
      }

      if (parts.length >= 2) break;
    }

    return parts.join(' • ');
  }
}
