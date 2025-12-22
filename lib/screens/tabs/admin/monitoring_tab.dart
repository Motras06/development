import 'package:flutter/material.dart';

class MonitoringTab extends StatelessWidget {
  const MonitoringTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor_heart, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Мониторинг системы',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Статистика активности пользователей\n'
            'Количество проектов, задач, сообщений\n'
            'Логи событий\n'
            'Обнаружение аномалий',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
