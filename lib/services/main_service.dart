import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';
import '/screens/tabs/admin/admin_home.dart';
import '/screens/tabs/client/client_home.dart';
import '/screens/tabs/leader/leader_home.dart';
import '/screens/tabs/worker/worker_home.dart';

class MainApp extends StatefulWidget {
  final String? initialRoleHint;

  const MainApp({super.key, this.initialRoleHint});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  Future<Widget> _getHomeScreen() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const LoginScreen();

    try {
      // Пробуем получить пользователя из public.users
      final userResponse = await _supabase
          .from('users')
          .select('is_admin')
          .eq('id', userId)
          .maybeSingle(); // ← maybeSingle вместо single — не упадёт, если нет строки

      if (userResponse != null && userResponse['is_admin'] == true) {
        return const AdminHome();
      }
    } catch (e) {
      debugPrint('Пользователь не найден в public.users: $e');
    }

    // Если нет в public.users или не админ — смотрим роли в проектах
    try {
      final participantResponse = await _supabase
          .from('project_participants')
          .select('role')
          .eq('user_id', userId);

      final roles = participantResponse.map((e) => e['role'] as String).toSet();

      if (roles.contains('leader')) return const LeaderHome();
      if (roles.contains('worker')) return const WorkerHome();
      if (roles.contains('client')) return const ClientHome();
    } catch (e) {
      debugPrint('Нет ролей в проектах: $e');
    }

    // Если вообще ничего нет — покажем базовый экран (можно сделать онбординг)
    return const ClientHome(); // или LeaderHome, или специальный "Нет доступа"
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getHomeScreen(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
