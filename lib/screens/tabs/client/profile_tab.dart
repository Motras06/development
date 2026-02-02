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
          .select('full_name, phone')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _fullName = response['full_name'] as String?;
          _phone = response['phone'] as String?;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки профиля: $e')));
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

      await supabase
          .from('users')
          .update({
            'full_name': _fullName?.trim().isNotEmpty == true
                ? _fullName!.trim()
                : null,
            'phone': _phone?.trim().isNotEmpty == true ? _phone!.trim() : null,
          })
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Профиль обновлён')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changePassword() async {
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
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Новый пароль'),
                validator: (v) {
                  if (v == null || v.trim().length < 8) {
                    return 'Минимум 8 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Повторите новый пароль',
                ),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.message)));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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

            Center(
              child: CircleAvatar(
                radius: 70,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  Icons.business_center,
                  size: 90,
                  color: colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              _fullName ?? 'Заказчик',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onBackground,
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

            const SizedBox(height: 12),

            Center(
              child: Chip(
                label: const Text(
                  'Заказчик',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.green.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.green),
                avatar: const Icon(
                  Icons.verified_user,
                  color: Colors.green,
                  size: 18,
                ),
              ),
            ),

            const SizedBox(height: 48),

            TextFormField(
              initialValue: _fullName,
              decoration: InputDecoration(
                labelText: 'ФИО / Название компании',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              onSaved: (v) => _fullName = v?.trim(),
              validator: (v) =>
                  v?.trim().isEmpty ?? true ? 'Укажите имя или название' : null,
            ),

            const SizedBox(height: 20),

            TextFormField(
              initialValue: _phone,
              decoration: InputDecoration(
                labelText: 'Телефон для связи',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              onSaved: (v) => _phone = v?.trim(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (v.trim().length < 10) return 'Некорректный номер';
                return null;
              },
            ),

            const SizedBox(height: 40),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'Сохранение...' : 'Сохранить изменения',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Сменить пароль'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
