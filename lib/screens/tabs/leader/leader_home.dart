import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';
import '/screens/tabs/leader/chat_and_docs_tab.dart';
import '/screens/tabs/leader/projects_tab.dart';
import '/screens/tabs/leader/stages_tab.dart';
import '/screens/tabs/leader/team_tab.dart';
import '/screens/tabs/leader/works_tab.dart';

class LeaderHome extends StatefulWidget {
  const LeaderHome({super.key});

  @override
  State<LeaderHome> createState() => _LeaderHomeState();
}

class _LeaderHomeState extends State<LeaderHome>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    ProjectsTab(),
    StagesTab(),
    WorksTab(),
    TeamTab(),
    ChatAndDocsTab(),
  ];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    _animationController.reverse().then((_) {
      setState(() {
        _selectedIndex = index;
      });
      _animationController.forward();
    });
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Ошибка при выходе: $e');
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    }
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme) {
    final isSelected = _selectedIndex == index;

    return BottomNavigationBarItem(
      icon: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: isSelected ? _scaleAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          );
        },
      ),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<String> titles = [
      'Мои проекты',
      'Этапы',
      'Работы',
      'Команда',
      'Чат и документы',
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primary.withOpacity(0.95),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _pages[_selectedIndex],
        key: ValueKey<int>(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: colorScheme.surface,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          items: [
            _buildNavItem(Icons.folder_special, 'Проекты', 0, colorScheme),
            _buildNavItem(Icons.view_week, 'Этапы', 1, colorScheme),
            _buildNavItem(Icons.assignment, 'Работы', 2, colorScheme),
            _buildNavItem(Icons.group, 'Команда', 3, colorScheme),
            _buildNavItem(Icons.chat_bubble, 'Чат', 4, colorScheme),
          ],
        ),
      ),
    );
  }
}