import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '/models/enums.dart';

class ChatAndDocsTab extends StatefulWidget {
  const ChatAndDocsTab({super.key});

  @override
  State<ChatAndDocsTab> createState() => _ChatAndDocsTabState();
}

class _ChatAndDocsTabState extends State<ChatAndDocsTab> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  List<Map<String, dynamic>> _messages = [];

  String? _currentUserId;
  RealtimeChannel? _channel;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _currentUserId = supabase.auth.currentUser?.id;
    _loadUserProjects();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProjects() async {
    if (_currentUserId == null) return;

    try {
      final created = await supabase
          .from('projects')
          .select('id, name, description')
          .eq('created_by', _currentUserId!)
          .order('created_at', ascending: false);

      final participant = await supabase
          .from('project_participants')
          .select('project_id, projects(id, name, description)')
          .eq('user_id', _currentUserId!);

      final participantProjects = participant
          .map((e) => e['projects'] as Map<String, dynamic>)
          .toList();

      final uniqueProjects = <String, Map<String, dynamic>>{};
      for (var p in [...created, ...participantProjects]) {
        uniqueProjects[p['id'] as String] = p;
      }

      setState(() {
        _projects = uniqueProjects.values.toList();
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });

      if (_selectedProject != null) {
        _subscribeToChannel();
      }
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  Future<void> _subscribeToChannel() async {
    if (_selectedProject == null || _currentUserId == null) return;

    await _channel?.unsubscribe();
    _channel = null;

    final projectId = _selectedProject!['id'] as String;

    _channel = supabase.channel('project-chat:$projectId');

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'project_id',
        value: projectId,
      ),
      callback: (payload) {
        final newMessage = payload.newRecord;
        if (newMessage['project_id'] == projectId) {
          setState(() {
            _messages.add(newMessage);
          });
          _scrollToBottom();
          _animController.forward(from: 0.0);
        }
      },
    );

    await _channel!.subscribe();

    await _loadInitialMessages();
  }

  Future<void> _loadInitialMessages() async {
    if (_selectedProject == null) return;

    try {
      final data = await supabase
          .from('messages')
          .select()
          .eq('project_id', _selectedProject!['id'])
          .order('created_at', ascending: true)
          .limit(300);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(data);
      });

      _scrollToBottom(animate: false);
      _animController.forward(from: 0.0);
    } catch (e) {
      debugPrint('Ошибка загрузки сообщений: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || _selectedProject == null) return;

    try {
      await supabase.from('messages').insert({
        'project_id': _selectedProject!['id'],
        'sender_id': _currentUserId,
        'text': text,
        'is_notification': false,
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          pos,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(pos);
      }
    });
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(  // ← SafeArea гарантирует, что контент не уйдёт под системные панели
        child: Column(
          children: [
            // Выбор проекта (Dropdown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                value: _selectedProject,
                hint: const Text('Выберите проект для чата'),
                underline: const SizedBox(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: _projects.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(p['name'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProject = value;
                    _messages = [];
                  });
                  _subscribeToChannel();
                },
              ),
            ),

            // Список сообщений
            Expanded(
              child: _selectedProject == null
                  ? const Center(child: Text('Выберите проект для чата'))
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] == _currentUserId;
                          final isNotification = msg['is_notification'] == true;
                          final text = msg['text'] as String? ?? '';
                          final time = _formatTime(msg['created_at'] as String?);

                          return GestureDetector(
                            onLongPress: () {
                              if (text.isNotEmpty) {
                                Clipboard.setData(ClipboardData(text: text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Скопировано')),
                                );
                              }
                            },
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: Material(
                                  elevation: isMe ? 1 : 0.5,
                                  shadowColor: Colors.black.withOpacity(0.12),
                                  color: isNotification
                                      ? Colors.orange.shade100
                                      : isMe
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe && !isNotification)
                                          FutureBuilder<String>(
                                            future: supabase
                                                .from('users')
                                                .select('full_name')
                                                .eq('id', msg['sender_id'])
                                                .maybeSingle()
                                                .then((data) => data?['full_name'] as String? ?? 'Аноним'),
                                            builder: (context, snapshot) {
                                              return Text(
                                                snapshot.data ?? 'Аноним',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              );
                                            },
                                          ),
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: isNotification ? Colors.orange.shade900 : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          time,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isMe
                                                ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            // Панель ввода — теперь внизу, над таббаром
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Сообщение...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    onPressed: _sendMessage,
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 2,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}