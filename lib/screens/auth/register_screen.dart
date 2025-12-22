import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/screens/auth/role_selection_screen.dart';
import '/services/main_service.dart'; // Твой файл с MainApp (AuthWrapper использует его)

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedRoleName; // Для отображения в кнопке
  String? _selectedRoleValue; // 'leader', 'worker', 'client' — сохраняется в metadata

  bool _isLoading = false;

  Future<void> _selectRole() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const RoleSelectionScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedRoleValue = result;
        _selectedRoleName = switch (result) {
          'leader' => 'Руководитель',
          'worker' => 'Работник',
          'client' => 'Заказчик',
          _ => null,
        };
      });
    }
  }

  Future<void> _register() async {
    // Проверка выбора роли
    if (_selectedRoleValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите роль')),
      );
      return;
    }

    // Проверка пароля
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль должен быть не менее 6 символов')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          if (_fullNameController.text.trim().isNotEmpty)
            'full_name': _fullNameController.text.trim(),
          if (_phoneController.text.trim().isNotEmpty)
            'phone': _phoneController.text.trim(),
          'preferred_role': _selectedRoleValue, // Сохраняем роль в metadata
        },
      );

      // Поскольку подтверждение email отключено — сессия сразу активна
      if (response.session != null && mounted) {
        // Переходим в основной интерфейс приложения
        // AuthWrapper автоматически определит сессию и покажет MainApp
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainApp()),
          (route) => false, // Удаляем все предыдущие экраны
        );
      } else if (response.user != null) {
        // На случай, если сессия null (редко), но пользователь создан
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Регистрация успешна! Войдите в аккаунт.')),
        );
        Navigator.pop(context); // Возврат на LoginScreen
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Произошла неизвестная ошибка')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Кнопка выбора роли — красивая, как в примере
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _selectRole,
                icon: Icon(
                  _selectedRoleValue == null ? Icons.person_outline : Icons.check_circle,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  _selectedRoleValue == null
                      ? 'Выберите роль'
                      : 'Роль: $_selectedRoleName',
                  style: const TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: theme.colorScheme.primary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'ФИО (опционально)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Телефон (опционально)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль (мин. 6 символов)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Зарегистрироваться',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}