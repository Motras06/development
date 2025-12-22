import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderHome extends StatefulWidget {
  const LeaderHome({super.key});

  @override
  State<LeaderHome> createState() => _LeaderHomeState();
}

class _LeaderHomeState extends State<LeaderHome> {
  final user = Supabase.instance.client.auth.currentUser;
  String? fullName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('users')
            .select('full_name')
            .eq('id', user!.id)
            .single();

        if (mounted) {
          setState(() {
            fullName = response['full_name'] as String?;
          });
        }
      } catch (e) {
        debugPrint('Ошибка загрузки имени: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = fullName?.isNotEmpty == true
        ? fullName
        : user?.email?.split('@').first ?? 'Руководитель';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Руководитель проектов'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.engineering,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                'Добро пожаловать!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                displayName!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                ),
                child: const Text(
                  'Роль: Руководитель',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Вы можете создавать новые проекты, управлять этапами и работами, добавлять участников команды, загружать документацию и отслеживать весь прогресс строительства.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}