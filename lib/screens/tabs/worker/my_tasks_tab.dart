import 'package:flutter/material.dart';

class MyTasksTab extends StatelessWidget {
  const MyTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Мои задачи',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Список всех назначенных на вас работ\n'
            'Фильтры: по статусу, этапу, просроченные\n'
            'Изменение статуса, сроков и комментариев',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
