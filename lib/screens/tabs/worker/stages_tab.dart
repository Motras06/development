import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/enums.dart';

class StagesTab extends StatefulWidget {
  const StagesTab({super.key});

  @override
  State<StagesTab> createState() => _StagesTabState();
}

class _StagesTabState extends State<StagesTab> {
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
      // Получаем ID проектов, где пользователь участвует
      final participantData = await _supabase
          .from('project_participants')
          .select('project_id, projects(name, description)')
          .eq('user_id', userId!);

      final projectIds = participantData.map((p) => p['project_id'] as String).toList();

      if (projectIds.isEmpty) {
        setState(() => _projects = []);
        return;
      }

      // Получаем сами проекты
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

  Future<void> _addComment(String stageId) async {
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Комментарий к этапу'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(hintText: 'Ваш комментарий'),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              if (commentController.text.trim().isEmpty) return;

              try {
                await _supabase.from('comments').insert({
                  'entity_type': CommentEntityType.stage.name,
                  'entity_id': stageId,
                  'user_id': userId,
                  'text': commentController.text.trim(),
                });

                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Комментарий добавлен')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
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

          // Поиск по этапам
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                labelText: 'Поиск по названию этапа',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Список этапов
          Expanded(
            child: _selectedProject == null
                ? const Center(child: Text('Выберите проект для просмотра этапов'))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('stages')
                        .stream(primaryKey: ['id'])
                        .eq('project_id', _selectedProject!['id'])
                        .order('created_at', ascending: true),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Ошибка: ${snapshot.error}'));
                      }

                      final stages = snapshot.data ?? [];

                      final filtered = stages.where((s) {
                        return (s['name'] as String)
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('Нет этапов в этом проекте'),
                        );
                      }

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final stage = filtered[index];
                          final name = stage['name'] as String;
                          final description = stage['description'] as String?;
                          final statusStr = stage['status'] as String;
                          final start = stage['start_date'] as String?;
                          final end = stage['end_date'] as String?;
                          final material = stage['material_resources'] as List<dynamic>?;
                          final nonMaterial = stage['non_material_resources'] as List<dynamic>?;

                          final status = StageStatus.values.firstWhere(
                            (e) => e.name == statusStr,
                            orElse: () => StageStatus.planned,
                          );

                          // Заглушка прогресса
                          final double progress = 0.55; // 55%

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 3,
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(status),
                                child: Text(
                                  status.name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Text(
                                '${start ?? '?'} — ${end ?? '?'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${(progress * 100).toInt()}%'),
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    width: 35,
                                    height: 35,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 5,
                                      backgroundColor: Colors.grey[300],
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                if (description != null && description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(description),
                                  ),
                                const SizedBox(height: 8),
                                if (material != null && material.isNotEmpty)
                                  _buildResourcesSection('Материальные ресурсы', material),
                                if (nonMaterial != null && nonMaterial.isNotEmpty)
                                  _buildResourcesSection('Нематериальные ресурсы', nonMaterial),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _addComment(stage['id']),
                                    icon: const Icon(Icons.comment),
                                    label: const Text('Оставить комментарий'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
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

  Widget _buildResourcesSection(String title, List<dynamic> resources) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ...resources.map((res) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  '• ${res['name']} ${res['quantity'] != null ? "— ${res['quantity']} ${res['unit'] ?? ''}" : ""}',
                ),
              )),
        ],
      ),
    );
  }

  Color _getStatusColor(StageStatus status) {
    return switch (status) {
      StageStatus.planned => Colors.grey,
      StageStatus.in_progress => Colors.blue,
      StageStatus.paused => Colors.orange,
      StageStatus.completed => Colors.green,
    };
  }
}