import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> with SingleTickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _currentUserId = supabase.auth.currentUser?.id;
    _loadMyProjects();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProjects() async {
    if (_currentUserId == null) return;

    try {
      final participantData = await supabase
          .from('project_participants')
          .select('project_id, projects(id, name, description)')
          .eq('user_id', _currentUserId!);

      final myProjects = participantData
          .map((e) => e['projects'] as Map<String, dynamic>)
          .toList();

      setState(() {
        _projects = myProjects;
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });

      if (_selectedProject != null) {
        _subscribeToChannel();
      }
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не удалось загрузить проекты')));
      }
    }
  }

  Future<void> _subscribeToChannel() async {
    if (_selectedProject == null || _currentUserId == null) return;

    await _channel?.unsubscribe();
    _channel = null;

    final projectId = _selectedProject!['id'] as String;

    _channel = supabase.channel('project-messages:$projectId');

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
        final newMsg = payload.newRecord;
        if (newMsg['project_id'] == projectId) {
          setState(() {
            _messages.add(newMsg);
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
          .limit(400);

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
    if (text.isEmpty || _currentUserId == null || _selectedProject == null)
      return;

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
          SnackBar(content: Text('Не удалось отправить сообщение')),
        );
      }
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_currentUserId == null) {
      return const Center(child: Text('Не авторизован'));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: _projects.isEmpty
                  ? const Text(
                      'Вы не участвуете ни в одном проекте',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    )
                  : DropdownButton<Map<String, dynamic>>(
                      value: _selectedProject,
                      isExpanded: true,
                      hint: const Text('Выберите проект'),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: _projects.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            p['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
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

            Expanded(
              child: _selectedProject == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 72,
                            color: colorScheme.primary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Выберите проект',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Чтобы начать общение в чате',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: RefreshIndicator(
                        onRefresh: _loadInitialMessages,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['sender_id'] == _currentUserId;
                            final isNotification =
                                msg['is_notification'] == true;
                            final text = msg['text'] as String? ?? '';
                            final time = _formatTime(
                              msg['created_at'] as String?,
                            );

                            return GestureDetector(
                              onLongPress: () {
                                if (text.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Текст скопирован'),
                                      duration: Duration(milliseconds: 1400),
                                    ),
                                  );
                                }
                              },
                              child: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                        0.78,
                                  ),
                                  child: Material(
                                    elevation: isMe ? 1.2 : 0.6,
                                    shadowColor: Colors.black.withOpacity(0.10),
                                    color: isNotification
                                        ? Colors.amber.shade50
                                        : isMe
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: Radius.circular(
                                        isMe ? 20 : 6,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 6 : 20,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe && !isNotification)
                                            FutureBuilder<String>(
                                              future: supabase
                                                  .from('users')
                                                  .select('full_name')
                                                  .eq('id', msg['sender_id'])
                                                  .maybeSingle()
                                                  .then(
                                                    (data) =>
                                                        data?['full_name']
                                                            as String? ??
                                                        'Неизвестно',
                                                  ),
                                              builder: (context, snapshot) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 4,
                                                      ),
                                                  child: Text(
                                                    snapshot.data ??
                                                        'Неизвестно',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          Text(
                                            text,
                                            style: TextStyle(
                                              height: 1.32,
                                              color: isNotification
                                                  ? Colors.amber.shade900
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            time,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontSize: 11,
                                                  color: isMe
                                                      ? colorScheme
                                                            .onPrimaryContainer
                                                            .withOpacity(0.75)
                                                      : colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.78),
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
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                        hintText: _selectedProject == null
                            ? 'Выберите проект...'
                            : 'Напишите сообщение...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (_selectedProject != null) _sendMessage();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.small(
                    onPressed: _selectedProject == null ? null : _sendMessage,
                    backgroundColor: _selectedProject == null
                        ? colorScheme.outline
                        : colorScheme.primary,
                    foregroundColor: _selectedProject == null
                        ? null
                        : colorScheme.onPrimary,
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
