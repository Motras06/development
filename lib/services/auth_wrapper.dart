import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';
import '/services/main_service.dart'; // Твой MainApp

/// Обёртка, которая реагирует на любые изменения авторизации в реальном времени
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Пока стрим инициализируется — показываем лоадер
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final AuthState? authState = snapshot.data;
        final AuthChangeEvent? event = authState?.event;

        // Явно обрабатываем событие выхода
        if (event == AuthChangeEvent.signedOut) {
          return const LoginScreen();
        }

        // Если есть активная сессия (вход или восстановление сессии)
        if (authState?.session != null) {
          return const MainApp();
        }

        // Во всех остальных случаях (нет сессии, ошибка и т.д.)
        return const LoginScreen();
      },
    );
  }
}