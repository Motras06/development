import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Добавь в pubspec.yaml: url_launcher: ^6.2.1

class DocumentsTab extends StatefulWidget {
  const DocumentsTab({super.key});

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  final _supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (userId == null) return;

    try {
      // Получаем проекты, где пользователь — client
      final participantData = await _supabase
          .from('project_participants')
          .select('project_id, projects(name, description)')
          .eq('user_id', userId!)
          .eq('role', 'client');

      final projectIds = participantData.map((p) => p['project_id'] as String).toList();

      if (projectIds.isEmpty) {
        setState(() => _projects = []);
        return;
      }

      final projectsData = await _supabase
          .from('projects')
          .select('id, name, description')
          .inFilter('id', projectIds)
          .order('created_at', ascending: false);

      setState(() {
        _projects = List<Map<String, dynamic>>.from(projectsData);
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть файл')),
      );
    }
  }

  Future<void> _downloadDocument(String url, String fileName) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Скачивание $fileName начато...')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось скачать файл')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Выбор проекта
          if (_projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButton<Map<String, dynamic>?>(
                isExpanded: true,
                hint: const Text('Выберите проект'),
                value: _selectedProject,
                items: _projects.map((project) {
                  return DropdownMenuItem(
                    value: project,
                    child: Text(project['name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedProject = value),
              ),
            ),

          // Поиск по документам
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                labelText: 'Поиск по названию документа',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Список документов
          Expanded(
            child: _selectedProject == null
                ? const Center(child: Text('Выберите проект для просмотра документов'))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('technical_documents')
                        .stream(primaryKey: ['id'])
                        .eq('project_id', _selectedProject!['id'])
                        .order('uploaded_at', ascending: false),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Ошибка: ${snapshot.error}'));
                      }

                      final documents = snapshot.data ?? [];

                      final filtered = documents.where((doc) {
                        return (doc['name'] as String)
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 80, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Нет документов',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Техническая документация появится после загрузки',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final name = doc['name'] as String;
                          final description = doc['description'] as String?;
                          final fileUrl = doc['file_url'] as String?;
                          final uploadedById = doc['uploaded_by'] as String?;
                          final uploadedAt = doc['uploaded_at'] as String?;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.description, size: 40, color: Colors.blue),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (description != null && description.isNotEmpty)
                                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  if (uploadedAt != null)
                                    Text(
                                      'Загружен: ${DateTime.parse(uploadedAt).toLocal().toString().split('.')[0]}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  if (uploadedById != null)
                                    FutureBuilder(
                                      future: _supabase
                                          .from('users')
                                          .select('full_name')
                                          .eq('id', uploadedById)
                                          .single(),
                                      builder: (context, userSnap) {
                                        final uploader = userSnap.data?['full_name'] ?? 'Неизвестно';
                                        return Text(
                                          'Автор: $uploader',
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (fileUrl == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Ссылка на файл отсутствует')),
                                    );
                                    return;
                                  }

                                  if (value == 'view') {
                                    _openDocument(fileUrl);
                                  } else if (value == 'download') {
                                    _downloadDocument(fileUrl, name);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'view', child: Text('Просмотреть')),
                                  const PopupMenuItem(value: 'download', child: Text('Скачать')),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}