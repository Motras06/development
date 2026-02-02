import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_explorer.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  final List<String> _tables = [
    'users',
    'projects',
    'stages',
    'works',
    'project_participants',
    'messages',
    'comments',
  ];

  Future<bool> _isAdmin() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await Supabase.instance.client
        .from('users')
        .select('is_admin')
        .eq('id', userId)
        .maybeSingle();

    return data?['is_admin'] == true;
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Вы вышли из аккаунта')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выходе: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 96,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Доступ запрещён',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Эта панель доступна только администраторам',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Вернуться'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Админ-панель'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Выйти из аккаунта',
                onPressed: _signOut,
              ),
            ],
          ),
          body: DatabaseExplorer(tableName: _tables[_selectedIndex]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: _tables.map((table) {
              return NavigationDestination(
                icon: _getIconForTable(table),
                label: _shortTableName(table),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Icon _getIconForTable(String table) {
    return switch (table) {
      'users' => const Icon(Icons.people_alt_rounded),
      'projects' => const Icon(Icons.folder_rounded),
      'stages' => const Icon(Icons.view_list_rounded),
      'works' => const Icon(Icons.construction_rounded),
      'project_participants' => const Icon(Icons.group_work_rounded),
      'messages' => const Icon(Icons.message_rounded),
      'comments' => const Icon(Icons.comment_rounded),
      _ => const Icon(Icons.table_rows_rounded),
    };
  }

  String _shortTableName(String table) {
    return table.split('_').map((e) => e[0].toUpperCase()).take(2).join();
  }
}
