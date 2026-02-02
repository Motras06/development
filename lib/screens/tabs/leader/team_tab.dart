import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class TeamTab extends StatefulWidget {
  const TeamTab({super.key});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  String _searchQuery = '';

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadProjects();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    if (_currentUserId == null) return;


    try {
      final data = await _supabase
          .from('projects')
          .select('id, name, description')
          .eq('created_by', _currentUserId)
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сначала выберите проект')));
      return;
    }

    final emailController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Пригласить участника',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'Email участника',
            hintText: 'example@email.com',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.email_outlined),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.08),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Пригласить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите email')));
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
          const SnackBar(content: Text('Этот участник уже в проекте')),
        );
        return;
      }

      const defaultRole = ParticipantRole.worker;

      await _supabase.from('project_participants').insert({
        'project_id': _selectedProject!['id'],
        'user_id': targetUserId,
        'role': defaultRole.name,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Участник успешно приглашён!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка приглашения: $e')));
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

    final name = participant['full_name'] as String? ?? 'участника';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить участника?'),
        content: Text('Вы действительно хотите удалить $name из проекта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.05),
              colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _selectedProject != null
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.4),
                    width: _selectedProject != null ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedProject != null
                          ? colorScheme.primary.withOpacity(0.25)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: _selectedProject != null ? 16 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>?>(
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_special_outlined,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Выберите проект',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    value: _selectedProject,
                    isExpanded: true,
                    icon: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: AnimatedRotation(
                        turns: _selectedProject != null ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _selectedProject != null
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.6),
                          size: 28,
                        ),
                      ),
                    ),
                    dropdownColor: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 8,
                    items: _projects.map((project) {
                      final String name = project['name'] as String;

                      return DropdownMenuItem<Map<String, dynamic>?>(
                        value: project,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_special,
                                color: colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: _selectedProject == project
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedProject == project)
                                Icon(
                                  Icons.check_circle,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedProject = v),
                    selectedItemBuilder: (context) {
                      return _projects.map<Widget>((project) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 7,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_special,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  project['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      labelText: 'Поиск по имени, email, телефону...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.08),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _selectedProject == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_off,
                            size: 80,
                            color: colorScheme.primary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Выберите проект',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Чтобы увидеть команду',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _supabase
                          .from('project_participants_with_users')
                          .stream(primaryKey: ['id'])
                          .eq('project_id', _selectedProject!['id'])
                          .order('joined_at'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Ошибка загрузки: ${snapshot.error}'),
                          );
                        }

                        final participants = snapshot.data ?? [];

                        final filtered = participants
                            .where((p) => p['user_id'] != _currentUserId)
                            .where((p) {
                              final n =
                                  (p['full_name'] as String?)?.toLowerCase() ??
                                  '';
                              final e =
                                  (p['email'] as String?)?.toLowerCase() ?? '';
                              final ph =
                                  (p['phone'] as String?)?.toLowerCase() ?? '';

                              final searchMatch =
                                  n.contains(_searchQuery) ||
                                  e.contains(_searchQuery) ||
                                  ph.contains(_searchQuery);

                              return searchMatch;
                            })
                            .toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.group_off,
                                  size: 80,
                                  color: colorScheme.primary.withOpacity(0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Участники не найдены',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Попробуйте изменить поиск или пригласить нового',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];

                            final name =
                                p['full_name'] as String? ?? 'Без имени';
                            final email = p['email'] as String? ?? '—';
                            final phone = p['phone'] as String?;

                            return AnimatedSlide(
                              duration: Duration(
                                milliseconds: 300 + index * 50,
                              ),
                              offset: Offset(0, index * 0.05),
                              curve: Curves.easeOutCubic,
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 3,
                                shadowColor: Colors.black.withOpacity(0.12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: colorScheme.primary,
                                    radius: 28,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (email != '—')
                                        Text(
                                          email,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface
                                                .withOpacity(0.75),
                                          ),
                                        ),
                                      if (phone != null)
                                        Text(
                                          phone,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurface
                                                .withOpacity(0.75),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: colorScheme.onSurface.withOpacity(
                                        0.6,
                                      ),
                                    ),
                                    onSelected: (v) {
                                      if (v == 'remove') _removeMember(p);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text(
                                          'Удалить из проекта',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
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

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: ScaleTransition(
          scale: _fabScaleAnimation,
          child: FloatingActionButton.extended(
            onPressed: _selectedProject == null ? null : _inviteMember,
            label: const Text('Пригласить'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            backgroundColor: _selectedProject == null
                ? Colors.grey
                : colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 12,
            tooltip: 'Пригласить участника',
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
