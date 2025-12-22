import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class TeamTab extends StatefulWidget {
  const TeamTab({super.key});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

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
      final data = await _supabase
          .from('projects')
          .select('id, name, description')
          .eq('created_by', userId!)
          .order('created_at', ascending: false);

      setState(() {
        _projects = List<Map<String, dynamic>>.from(data);
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  Future<void> _inviteMember() async {
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите проект')),
      );
      return;
    }

    final emailController = TextEditingController();
    ParticipantRole? selectedRole = ParticipantRole.worker;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Пригласить участника'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email приглашаемого',
                    hintText: 'example@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButton<ParticipantRole>(
                  value: selectedRole,
                  isExpanded: true,
                  hint: const Text('Выберите роль'),
                  items: ParticipantRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_roleDisplayName(role)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedRole = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty || selectedRole == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Заполните все поля')),
                    );
                    return;
                  }

                  try {
                    final userData = await _supabase
                        .from('users')
                        .select('id')
                        .eq('email', email)
                        .maybeSingle();

                    if (userData == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Пользователь с таким email не найден')),
                      );
                      return;
                    }

                    final targetUserId = userData['id'];

                    // Проверка на дубликат
                    final existing = await _supabase
                        .from('project_participants')
                        .select()
                        .eq('project_id', _selectedProject!['id'])
                        .eq('user_id', targetUserId)
                        .maybeSingle();

                    if (existing != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Пользователь уже в проекте')),
                      );
                      Navigator.pop(context);
                      return;
                    }

                    await _supabase.from('project_participants').insert({
                      'project_id': _selectedProject!['id'],
                      'user_id': targetUserId,
                      'role': selectedRole!.name,
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Участник успешно приглашён!')),
                      );
                    }
                    Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка приглашения: $e')),
                      );
                    }
                  }
                },
                child: const Text('Пригласить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeRole(Map<String, dynamic> participant) async {
    final currentRoleStr = participant['role'] as String;
    ParticipantRole? newRole = ParticipantRole.values.firstWhere(
      (r) => r.name == currentRoleStr,
      orElse: () => ParticipantRole.worker,
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Изменить роль'),
            content: DropdownButton<ParticipantRole>(
              value: newRole,
              isExpanded: true,
              items: ParticipantRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(_roleDisplayName(role)),
                );
              }).toList(),
              onChanged: (value) => setDialogState(() => newRole = value),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              TextButton(
                onPressed: () async {
                  try {
                    await _supabase
                        .from('project_participants')
                        .update({'role': newRole!.name})
                        .eq('id', participant['id']);
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка изменения роли: $e')),
                    );
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeMember(Map<String, dynamic> participant) async {
    final userData = participant['users'] as Map<String, dynamic>?;
    final email = userData?['email'] as String? ?? 'пользователя';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить участника'),
        content: Text('Вы уверены, что хотите удалить $email из проекта?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase
            .from('project_participants')
            .delete()
            .eq('id', participant['id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Участник удалён из проекта')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _inviteMember,
        label: const Text('Пригласить'),
        icon: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          // Выбор проекта
          if (_projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                hint: const Text('Выберите проект'),
                value: _selectedProject,
                items: _projects.map((project) {
                  return DropdownMenuItem(
                    value: project,
                    child: Text(project['name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedProject = value),
              ),
            ),

          // Поиск по участникам
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                labelText: 'Поиск по имени или email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Список участников
          Expanded(
            child: _selectedProject == null
                ? const Center(child: Text('Выберите проект для просмотра команды'))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('project_participants')
                        .stream(primaryKey: ['id'])
                        .eq('project_id', _selectedProject!['id'])
                        .order('joined_at', ascending: true)
                        .select('*, users(full_name, email, phone)'), // ← КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Ошибка: ${snapshot.error}'));
                      }

                      final participants = snapshot.data ?? [];

                      final filtered = participants.where((p) {
                        final user = p['users'] as Map<String, dynamic>?;
                        final email = (user?['email'] as String?)?.toLowerCase() ?? '';
                        final name = (user?['full_name'] as String?)?.toLowerCase() ?? '';
                        return email.contains(_searchQuery.toLowerCase()) ||
                            name.contains(_searchQuery.toLowerCase());
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('В этом проекте пока нет участников'));
                      }

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final participant = filtered[index];
                          final user = participant['users'] as Map<String, dynamic>?;
                          final roleStr = participant['role'] as String;

                          final role = ParticipantRole.values.firstWhere(
                            (r) => r.name == roleStr,
                            orElse: () => ParticipantRole.worker,
                          );

                          final fullName = user?['full_name'] as String? ?? 'Без имени';
                          final email = user?['email'] as String? ?? 'Email не указан';
                          final phone = user?['phone'] as String?;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getRoleColor(role),
                              child: Text(
                                role.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email),
                                if (phone != null) Text(phone),
                                Text(
                                  'Роль: ${_roleDisplayName(role)}',
                                  style: TextStyle(color: _getRoleColor(role)),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'change_role') _changeRole(participant);
                                if (value == 'remove') _removeMember(participant);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'change_role', child: Text('Изменить роль')),
                                const PopupMenuItem(value: 'remove', child: Text('Удалить из проекта')),
                              ],
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

  Color _getRoleColor(ParticipantRole role) {
    return switch (role) {
      ParticipantRole.leader => Colors.blue,
      ParticipantRole.worker => Colors.green,
      ParticipantRole.client => Colors.orange,
      ParticipantRole.admin => Colors.purple,
    };
  }

  String _roleDisplayName(ParticipantRole role) {
    return switch (role) {
      ParticipantRole.leader => 'Руководитель',
      ParticipantRole.worker => 'Работник',
      ParticipantRole.client => 'Заказчик',
      ParticipantRole.admin => 'Администратор',
    };
  }
}

extension on SupabaseStreamBuilder {
  Stream<List<Map<String, dynamic>>>? select(String s) {
    return null;
  }
}