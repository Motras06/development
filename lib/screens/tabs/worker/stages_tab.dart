import 'package:flutter/material.dart';

class StagesTab extends StatelessWidget {
  const StagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.view_timeline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Этапы проекта',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Просмотр всех этапов текущего проекта\n'
            'Описание, ресурсы, сроки\n'
            'Возможность оставлять комментарии',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
