import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  List<Map<String, dynamic>> _messages = [];

  String? _currentUserId;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _loadMyProjects();
  }

  Future<void> _loadMyProjects() async {
    if (_currentUserId == null) return;

    try {
      // Получаем только проекты, где пользователь — участник
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
    } catch (e) {
      debugPrint('Ошибка загрузки моих проектов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить проекты: $e')),
        );
      }
    }
  }

  Future<void> _subscribeToChannel() async {
    if (_selectedProject == null || _currentUserId == null) return;

    await _channel?.unsubscribe();
    _channel = null;

    final projectId = _selectedProject!['id'] as String;

    _channel = supabase.channel('messages_worker:$projectId');

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
        if (newMessage != null) {
          setState(() {
            _messages.add(newMessage);
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedProject != null) {
      _subscribeToChannel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('Не авторизован'));
    }

    return Scaffold(
      body: Column(
        children: [
          // Выбор проекта (только те, где ты участник)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _projects.isEmpty
                      ? const Text(
                          'Ты пока не приглашён ни в один проект',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )
                      : DropdownButton<Map<String, dynamic>>(
                          isExpanded: true,
                          value: _selectedProject,
                          hint: const Text('Выбери проект для чата'),
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
              ],
            ),
          ),

          // Список сообщений
          Expanded(
            child: _selectedProject == null
                ? const Center(child: Text('Выбери проект, чтобы увидеть чат'))
                : RefreshIndicator(
                    onRefresh: _loadInitialMessages,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['sender_id'] == _currentUserId;
                        final isNotification = msg['is_notification'] == true;

                        final text = msg['text'] as String? ?? '';
                        final createdAt = msg['created_at'] as String?;
                        final time = createdAt != null
                            ? DateFormat('HH:mm').format(DateTime.parse(createdAt))
                            : '';

                        return FutureBuilder<String>(
                          future: msg['sender_id'] != null
                              ? supabase
                                  .from('users')
                                  .select('full_name')
                                  .eq('id', msg['sender_id'])
                                  .maybeSingle()
                                  .then((data) => data?['full_name'] as String? ?? 'Аноним')
                              : Future.value('Система'),
                          builder: (context, snapshot) {
                            final senderName = snapshot.data ?? 'Аноним';

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isNotification
                                      ? Colors.orange.shade100
                                      : isMe
                                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe && !isNotification)
                                      Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
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
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),

      // Панель ввода сообщений — всегда внизу
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _selectedProject == null
                      ? 'Выбери проект...'
                      : 'Напиши сообщение...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                enabled: _selectedProject != null,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.send,
                color: _selectedProject == null ? Colors.grey : Colors.blue,
              ),
              onPressed: _selectedProject == null ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}