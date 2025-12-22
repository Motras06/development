import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_preview/device_preview.dart'; // ← Добавляем Device Preview

import '/screens/auth/login_screen.dart';
import '/services/main_service.dart'; // Твой файл с MainApp и логикой ролей

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем .env файл
  await dotenv.load(fileName: ".env");

  // Инициализируем Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    DevicePreview(
      enabled: true, // В продакшене можно сделать !kReleaseMode
      tools: const [
        ...DevicePreview.defaultTools,
        // Можно добавить/убрать инструменты по желанию
      ],
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Стройка Трекер',
      debugShowCheckedModeBanner: false,
      useInheritedMediaQuery: true, // Требуется для Device Preview
      locale: DevicePreview.locale(context), // Для тестирования локалей
      builder: DevicePreview.appBuilder, // Важно! Обязательно для правильной работы
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const AuthWrapper(),
    );
  }
}

/// Обёртка, которая проверяет текущую сессию и направляет на нужный экран
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final authState = snapshot.data;

        if (authState?.event == AuthChangeEvent.signedIn ||
            authState?.session != null) {
          return const MainApp();
        }

        return const LoginScreen();
      },
    );
  }
}