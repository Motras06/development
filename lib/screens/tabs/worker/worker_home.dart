import 'package:development/screens/tabs/worker/chat_tab.dart';
import 'package:development/screens/tabs/worker/my_projects_tab.dart';
import 'package:development/screens/tabs/worker/my_tasks_tab.dart';
import 'package:development/screens/tabs/worker/stages_tab.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';

class WorkerHome extends StatefulWidget {
  const WorkerHome({super.key});

  @override
  State<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<WorkerHome> {
  int _selectedIndex = 0;

  // Список экранов для вкладок работника
  static final List<Widget> _pages = <Widget>[
    const MyProjectsTab(),
    const MyTasksTab(),
    const StagesTab(),
    const ChatTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Функция выхода из аккаунта
  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Работник'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.workspaces),
            label: 'Мои проекты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
            label: 'Мои задачи',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_timeline),
            label: 'Этапы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Чат',
          ),
        ],
      ),
    );
  }
}
