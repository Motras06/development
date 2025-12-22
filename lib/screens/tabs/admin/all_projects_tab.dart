import 'package:flutter/material.dart';

class AllProjectsTab extends StatelessWidget {
  const AllProjectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_shared, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Все проекты системы',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Обзор всех проектов в приложении\n'
            'Фильтрация по статусу, дате, руководителю\n'
            'Просмотр участников и прогресса\n'
            'Архивация/удаление при необходимости',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
