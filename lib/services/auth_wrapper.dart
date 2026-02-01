import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';
import '/services/main_service.dart'; // Твой MainApp
import 'package:permission_handler/permission_handler.dart';

/// Обёртка, которая реагирует на любые изменения авторизации в реальном времени
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Запрашиваем разрешения сразу после инициализации виджета
    if (Platform.isAndroid) {
      _requestStoragePermissions();
    }
  }

  /// Запрос разрешений на доступ к хранилищу (Android)
  Future<void> _requestStoragePermissions() async {
    // Определяем версию Android
    final sdkInt = await _getAndroidSdkVersion();

    Map<Permission, PermissionStatus> statuses;

    if (sdkInt >= 33) {
      // Android 13+: granular permissions (фото, видео, аудио)
      statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
    } else {
      // Android 12 и ниже: legacy storage
      statuses = await [Permission.storage].request();
    }

    // Проверяем, дали ли разрешение
    final hasPermission = statuses.values.any((s) => s.isGranted || s.isLimited);

    if (!hasPermission && mounted) {
      // Показываем SnackBar с кнопкой в настройки
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Для скачивания и открытия файлов нужно разрешение на доступ к хранилищу'),
          action: SnackBarAction(
            label: 'Открыть настройки',
            onPressed: () async {
              await openAppSettings();
            },
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  /// Получаем версию Android SDK
  Future<int> _getAndroidSdkVersion() async {
    try {
      final version = Platform.version;
      final match = RegExp(r'Android (\d+)').firstMatch(version);
      return int.tryParse(match?.group(1) ?? '33') ?? 33;
    } catch (_) {
      return 33; // по умолчанию считаем Android 13+
    }
  }

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