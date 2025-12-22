import 'package:flutter/material.dart';

class MyProjectsTab extends StatelessWidget {
  const MyProjectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspaces, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Мои проекты',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Список проектов, в которых вы участвуете\n'
            'Краткая информация: название, текущий этап, общий прогресс\n'
            'Уведомления о новых назначениях',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
