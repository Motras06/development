import 'package:development/screens/tabs/client/chat_tab.dart';
import 'package:development/screens/tabs/client/documents_tab.dart';
import 'package:development/screens/tabs/client/my_projects_tab.dart';
import 'package:development/screens/tabs/client/profile_tab.dart';
import 'package:development/screens/tabs/client/progress_tab.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int _selectedIndex = 0;

  // Список экранов для вкладок
  static final List<Widget> _pages = <Widget>[
    const MyProjectsTab(),
    const ProgressTab(),
    const DocumentsTab(),
    const ChatTab(),
    const ProfileTab()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Функция выхода из аккаунта
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
        title: const Text('Заказчик'),
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
            icon: Icon(Icons.folder_open),
            label: 'Мои проекты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'Прогресс',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Документы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Чат',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
