import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/login_screen.dart';
import '/services/main_service.dart';
import 'package:permission_handler/permission_handler.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _requestStoragePermissions();
    }
  }

  Future<void> _requestStoragePermissions() async {
    final sdkInt = await _getAndroidSdkVersion();

    Map<Permission, PermissionStatus> statuses;

    if (sdkInt >= 33) {
      statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
    } else {
      statuses = await [Permission.storage].request();
    }

    final hasPermission = statuses.values.any(
      (s) => s.isGranted || s.isLimited,
    );

    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Для скачивания и открытия файлов нужно разрешение на доступ к хранилищу',
          ),
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

  Future<int> _getAndroidSdkVersion() async {
    try {
      final version = Platform.version;
      final match = RegExp(r'Android (\d+)').firstMatch(version);
      return int.tryParse(match?.group(1) ?? '33') ?? 33;
    } catch (_) {
      return 33;
    }
  }

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

        final AuthState? authState = snapshot.data;
        final AuthChangeEvent? event = authState?.event;

        if (event == AuthChangeEvent.signedOut) {
          return const LoginScreen();
        }

        if (authState?.session != null) {
          return const MainApp();
        }

        return const LoginScreen();
      },
    );
  }
}
