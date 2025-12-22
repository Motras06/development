import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';
import '/screens/tabs/admin/admin_home.dart';
import '/screens/tabs/client/client_home.dart';
import '/screens/tabs/leader/leader_home.dart';
import '/screens/tabs/worker/worker_home.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data?.session;

        if (session == null) {
          return const LoginScreen();
        }

        return FutureBuilder<Widget>(
          future: _determineHomeScreen(),
          builder: (context, homeSnapshot) {
            if (homeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (homeSnapshot.hasData) {
              return homeSnapshot.data!;
            }

            return const ClientHome(); // Запасной вариант
          },
        );
      },
    );
  }

  Future<Widget> _determineHomeScreen() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const LoginScreen();

    try {
      final userData = await _supabase
          .from('users')
          .select('is_admin, primary_role')
          .eq('id', userId)
          .maybeSingle();

      if (userData == null) {
        return const ClientHome(); // Нет записи — дефолт
      }

      if (userData['is_admin'] == true) {
        return const AdminHome();
      }

      final role = userData['primary_role'] as String?;

      switch (role) {
        case 'leader':
          return const LeaderHome();
        case 'worker':
          return const WorkerHome();
        case 'client':
          return const ClientHome();
        default:
          return const AdminHome(); // Или онбординг "Выберите роль"
      }
    } catch (e) {
      debugPrint('Ошибка определения роли: $e');
      return const ClientHome();
    }
  }
}