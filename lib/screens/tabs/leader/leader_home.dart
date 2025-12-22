import 'package:development/screens/tabs/leader/chat_and_docs_tab.dart';
import 'package:development/screens/tabs/leader/projects_tab.dart';
import 'package:development/screens/tabs/leader/stages_tab.dart';
import 'package:development/screens/tabs/leader/team_tab.dart';
import 'package:development/screens/tabs/leader/works_tab.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';

class LeaderHome extends StatefulWidget {
  const LeaderHome({super.key});

  @override
  State<LeaderHome> createState() => _LeaderHomeState();
}

class _LeaderHomeState extends State<LeaderHome> {
  int _selectedIndex = 0;

  // Список экранов для 5 вкладок руководителя
  static final List<Widget> _pages = <Widget>[
    const ProjectsTab(),
    const StagesTab(),
    const WorksTab(),
    const TeamTab(),
    const ChatAndDocsTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (e) {
    debugPrint('Ошибка при выходе: $e');
  }

  if (mounted) {
    // Полная очистка навигации и переход на LoginScreen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false, // Удаляем ВСЕ маршруты из стека
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Руководитель'),
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
        type: BottomNavigationBarType.fixed, // Важно для 5+ вкладок
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_special),
            label: 'Проекты',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.view_week), label: 'Этапы'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Работы',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Команда'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Чат & Доки',
          ),
        ],
      ),
    );
  }
}
