import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class ChatAndDocsTab extends StatefulWidget {
  const ChatAndDocsTab({super.key});

  @override
  State<ChatAndDocsTab> createState() => _ChatAndDocsTabState();
}

class _ChatAndDocsTabState extends State<ChatAndDocsTab> {
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
    _loadUserProjects();
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
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  Future<void> _subscribeToChannel() async {
    if (_selectedProject == null || _currentUserId == null) return;

    await _channel?.unsubscribe();
    _channel = null;

    final projectId = _selectedProject!['id'] as String;

    _channel = supabase.channel('messages:$projectId');

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
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('Не авторизован'));
    }

    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              // Выбор проекта
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
                              'Нет доступных проектов',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            )
                          : DropdownButton<Map<String, dynamic>>(
                              isExpanded: true,
                              value: _selectedProject,
                              hint: const Text('Выберите проект для чата'),
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
                    ? const Center(child: Text('Выберите проект, чтобы увидеть чат'))
                    : RefreshIndicator(
                        onRefresh: _loadInitialMessages,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100), // отступ под панель ввода
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
        ),

        // Панель ввода сообщения — всегда внизу
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              8 + MediaQuery.of(context).padding.bottom,
            ),
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
                          ? 'Выберите проект...'
                          : 'Напишите сообщение...',
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
        ),
      ],
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