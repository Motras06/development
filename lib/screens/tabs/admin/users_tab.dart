import 'package:flutter/material.dart';

class UsersTab extends StatelessWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_alt, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Управление пользователями',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Список всех зарегистрированных пользователей\n'
            'Просмотр профилей\n'
            'Назначение/снятие роли администратора\n'
            'Блокировка/разблокировка аккаунтов',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
