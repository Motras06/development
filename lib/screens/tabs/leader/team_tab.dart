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
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  String _searchQuery = '';

  bool _isLoadingProjects = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (_currentUserId == null) return;

    setState(() => _isLoadingProjects = true);

    try {
      final data = await _supabase
          .from('projects')
          .select('id, name, description')
          .eq('created_by', _currentUserId!)
          .order('created_at', ascending: false);

      setState(() {
        _projects = List<Map<String, dynamic>>.from(data);
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProjects = false);
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Пригласить участника'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email участника',
                  hintText: 'example@email.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<ParticipantRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Роль',
                  border: OutlineInputBorder(),
                ),
                items: ParticipantRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(_roleDisplayName(role)),
                  );
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedRole = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Пригласить'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

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
          const SnackBar(content: Text('Пользователь не найден')),
        );
        return;
      }

      final targetUserId = userData['id'] as String;

      if (targetUserId == _currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя пригласить самого себя')),
        );
        return;
      }

      final existing = await _supabase
          .from('project_participants')
          .select('id')
          .eq('project_id', _selectedProject!['id'])
          .eq('user_id', targetUserId)
          .maybeSingle();

      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Участник уже в проекте')),
        );
        return;
      }

      await _supabase.from('project_participants').insert({
        'project_id': _selectedProject!['id'],
        'user_id': targetUserId,
        'role': selectedRole!.name,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Участник успешно приглашён!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка приглашения: $e')),
      );
    }
  }

  Future<void> _changeRole(Map<String, dynamic> participant) async {
    final participantUserId = participant['user_id'] as String?;

    if (participantUserId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя изменить свою роль')),
      );
      return;
    }

    ParticipantRole currentRole = ParticipantRole.values.firstWhere(
      (r) => r.name == (participant['role'] as String),
      orElse: () => ParticipantRole.worker,
    );

    final newRole = await showDialog<ParticipantRole?>(
      context: context,
      builder: (context) {
        ParticipantRole? temp = currentRole;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Изменить роль'),
            content: DropdownButton<ParticipantRole>(
              value: temp,
              isExpanded: true,
              items: ParticipantRole.values.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(_roleDisplayName(r)),
                  )).toList(),
              onChanged: (v) => setState(() => temp = v),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              TextButton(
                onPressed: () => Navigator.pop(context, temp),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );

    if (newRole == null || newRole == currentRole) return;

    try {
      await _supabase
          .from('project_participants')
          .update({'role': newRole.name})
          .eq('id', participant['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Роль обновлена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _removeMember(Map<String, dynamic> participant) async {
    final participantUserId = participant['user_id'] as String?;

    if (participantUserId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя удалить себя из проекта')),
      );
      return;
    }

    final user = participant['users'] as Map<String, dynamic>?;
    final name = user?['full_name'] as String? ?? 'участника';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить участника?'),
        content: Text('Вы действительно хотите удалить $name из проекта?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              // Выбор проекта
              if (_isLoadingProjects)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_projects.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('У вас пока нет проектов')),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: _selectedProject,
                    hint: const Text('Выберите проект'),
                    items: _projects.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p['name'] as String),
                        )).toList(),
                    onChanged: (v) => setState(() => _selectedProject = v),
                  ),
                ),

              // Поиск
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    labelText: 'Поиск по имени, email, телефону...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.08),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: _selectedProject == null
                    ? const Center(child: Text('Выберите проект для просмотра команды'))
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _supabase
                            .from('project_participants')
                            .stream(primaryKey: ['id'])
                            .eq('project_id', _selectedProject!['id'])
                            .order('joined_at'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
                          }

                          final participants = snapshot.data ?? [];

                          // Исключаем себя из списка
                          final filtered = participants
                              .where((p) => p['user_id'] != _currentUserId)
                              .where((p) {
                            final u = p['users'] as Map<String, dynamic>?;
                            final n = (u?['full_name'] as String?)?.toLowerCase() ?? '';
                            final e = (u?['email'] as String?)?.toLowerCase() ?? '';
                            final ph = (u?['phone'] as String?)?.toLowerCase() ?? '';
                            return n.contains(_searchQuery) ||
                                e.contains(_searchQuery) ||
                                ph.contains(_searchQuery);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(child: Text('Участники не найдены'));
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              final u = p['users'] as Map<String, dynamic>?;
                              final role = ParticipantRole.values.firstWhere(
                                (r) => r.name == (p['role'] as String),
                                orElse: () => ParticipantRole.worker,
                              );

                              final name = u?['full_name'] as String? ?? 'Без имени';
                              final email = u?['email'] as String? ?? '—';
                              final phone = u?['phone'] as String?;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getRoleColor(role),
                                    child: Text(
                                      name.isNotEmpty ? name[0] : '?',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(email, style: const TextStyle(fontSize: 13)),
                                      if (phone != null) Text(phone, style: const TextStyle(fontSize: 13)),
                                      Text(
                                        'Роль: ${_roleDisplayName(role)}',
                                        style: TextStyle(color: _getRoleColor(role), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'change_role') _changeRole(p);
                                      if (v == 'remove') _removeMember(p);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'change_role', child: Text('Изменить роль')),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Удалить из проекта', style: TextStyle(color: Colors.red)),
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
            ],
          ),
        ),

        // Кнопка «Пригласить» поверх всего, всегда видна
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.extended(
            heroTag: 'invite_team_fab',
            onPressed: _selectedProject == null ? null : _inviteMember,
            label: const Text('Пригласить'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            backgroundColor: _selectedProject == null ? Colors.grey : null,
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(ParticipantRole role) {
    return switch (role) {
      ParticipantRole.leader => Colors.blue.shade700,
      ParticipantRole.worker => Colors.green.shade600,
      ParticipantRole.client => Colors.orange.shade700,
      ParticipantRole.admin => Colors.purple.shade600,
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