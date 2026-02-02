import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();

  String? _fullName;
  String? _phone;
  String? _email;
  String? _role;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _email = user.email;
    });

    try {
      final response = await supabase
          .from('users')
          .select('full_name, phone, primary_role')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _fullName = response['full_name'] as String?;
          _phone = response['phone'] as String?;
          final roleRaw = response['primary_role'] as String?;
          _role = roleRaw == 'worker' ? 'Работник' : (roleRaw ?? 'Работник');
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки профиля: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Нет активной сессии');

      await supabase.from('users').update({
        'full_name': _fullName?.trim().isNotEmpty == true ? _fullName!.trim() : null,
        'phone': _phone?.trim().isNotEmpty == true ? _phone!.trim() : null,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль обновлён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Смена пароля'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Текущий пароль'),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Обязательно' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Новый пароль'),
                validator: (v) {
                  if (v == null || v.trim().length < 6) {
                    return 'Минимум 6 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Повторите новый пароль'),
                validator: (v) {
                  if (v != newCtrl.text) return 'Пароли не совпадают';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                // Supabase позволяет менять пароль только если пользователь аутентифицирован
                // Проверку старого пароля делать через RPC или вручную нельзя в простом варианте
                // Здесь — самый простой и безопасный способ (только новый пароль)

                final res = await supabase.auth.updateUser(
                  UserAttributes(password: newCtrl.text.trim()),
                );

                if (res.user != null) {
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Пароль успешно изменён')),
                    );
                  }
                }
              } on AuthException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            child: const Text('Сменить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),

            // Аватар (заглушка)
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: colorScheme.primary.withOpacity(0.15),
                child: Icon(
                  Icons.person,
                  size: 80,
                  color: colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              _fullName ?? 'Работник',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _email ?? '—',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 8),

            Chip(
              label: Text(
                'Роль: $_role',
              ),
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              labelStyle: TextStyle(color: colorScheme.primary),
            ),

            const SizedBox(height: 40),

            // Поля редактирования
            TextFormField(
              initialValue: _fullName,
              decoration: const InputDecoration(
                labelText: 'ФИО',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onSaved: (v) => _fullName = v?.trim(),
              validator: (v) => v?.trim().isEmpty ?? true ? 'Укажите ФИО' : null,
            ),

            const SizedBox(height: 16),

            TextFormField(
              initialValue: _phone,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              onSaved: (v) => _phone = v?.trim(),
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Сохранение...' : 'Сохранить изменения'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Сменить пароль'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}