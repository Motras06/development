import 'package:flutter/material.dart';

class ChatAndDocsTab extends StatelessWidget {
  const ChatAndDocsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Чат & Документы',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Групповой и личный чат проекта\n'
            'Список технической документации\n'
            'Загрузка новых документов\n'
            'Комментарии и уведомления',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
