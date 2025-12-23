import 'package:development/screens/settings/app_colors.dart';
import 'package:development/services/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_preview/device_preview.dart'; // ← Добавляем Device Preview

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
      theme: AppColors.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

