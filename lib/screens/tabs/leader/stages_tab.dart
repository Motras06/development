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
    try {
      final data = await _supabase
          .from('projects')
          .select('id, name, description, status')
          .eq('created_by', userId!)
          .order('created_at', ascending: false);

      setState(() {
        _projects = List<Map<String, dynamic>>.from(data);
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки проектов: $e');
    }
  }

  Future<void> _createStage() async {
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите проект')),
      );
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    List<Map<String, dynamic>> materialResources = [];
    List<Map<String, dynamic>> nonMaterialResources = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новый этап'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название этапа'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Описание'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(startDate == null ? 'Дата начала' : startDate!.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                ListTile(
                  title: Text(endDate == null ? 'Дата окончания' : endDate!.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => endDate = picked);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Материальные ресурсы', style: TextStyle(fontWeight: FontWeight.bold)),
                ...materialResources.map((res) => ListTile(
                      title: Text('${res['name']} — ${res['quantity']} ${res['unit']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => setDialogState(() => materialResources.remove(res)),
                      ),
                    )),
                TextButton(
                  onPressed: () => _addResourceDialog(setDialogState, materialResources, true),
                  child: const Text('+ Добавить материал'),
                ),
                const SizedBox(height: 16),
                const Text('Нематериальные ресурсы', style: TextStyle(fontWeight: FontWeight.bold)),
                ...nonMaterialResources.map((res) => ListTile(
                      title: Text(res['name']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => setDialogState(() => nonMaterialResources.remove(res)),
                      ),
                    )),
                TextButton(
                  onPressed: () => _addResourceDialog(setDialogState, nonMaterialResources, false),
                  child: const Text('+ Добавить ресурс'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                try {
                  await _supabase.from('stages').insert({
                    'project_id': _selectedProject!['id'],
                    'name': nameController.text.trim(),
                    'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                    'start_date': startDate?.toIso8601String().split('T').first,
                    'end_date': endDate?.toIso8601String().split('T').first,
                    'status': StageStatus.planned.name,
                    'material_resources': materialResources.isEmpty ? null : materialResources,
                    'non_material_resources': nonMaterialResources.isEmpty ? null : nonMaterialResources,
                  });

                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка создания этапа: $e')),
                    );
                  }
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _addResourceDialog(
    StateSetter setDialogState,
    List<Map<String, dynamic>> list,
    bool isMaterial,
  ) async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isMaterial ? 'Материальный ресурс' : 'Нематериальный ресурс'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            if (isMaterial) ...[
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Количество'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Единица (шт, м³ и т.д.)'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;

              final resource = {
                'name': nameController.text.trim(),
                if (isMaterial && quantityController.text.isNotEmpty)
                  'quantity': double.tryParse(quantityController.text) ?? 1,
                if (isMaterial && unitController.text.isNotEmpty)
                  'unit': unitController.text.trim(),
              };

              setDialogState(() => list.add(resource));
              Navigator.pop(context);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createStage,
        label: const Text('Новый этап'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Выбор проекта
          if (_projects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButton<Map<String, dynamic>>(
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

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStageStatusColor(status),
                                child: Text(status.name[0].toUpperCase()),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${start ?? '?'} — ${end ?? '?'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              children: [
                                if (description != null && description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(description),
                                  ),
                                const SizedBox(height: 8),
                                if (material != null && material.isNotEmpty)
                                  _buildResourcesList('Материальные ресурсы', material),
                                if (nonMaterial != null && nonMaterial.isNotEmpty)
                                  _buildResourcesList('Нематериальные ресурсы', nonMaterial),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _editStage(stage),
                                      child: const Text('Редактировать'),
                                    ),
                                    TextButton(
                                      onPressed: () => _changeStageStatus(stage),
                                      child: Text(status == StageStatus.paused ? 'Возобновить' : 'Приостановить'),
                                    ),
                                  ],
                                ),
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

  Widget _buildResourcesList(String title, List<dynamic> resources) {
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

  Color _getStageStatusColor(StageStatus status) {
    return switch (status) {
      StageStatus.planned => Colors.grey,
      StageStatus.in_progress => Colors.blue,
      StageStatus.paused => Colors.orange,
      StageStatus.completed => Colors.green,
    };
  }

  // Заглушки для редактирования и изменения статуса (можно реализовать позже)
  void _editStage(Map<String, dynamic> stage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Редактирование этапа: ${stage['name']}')),
    );
  }

  void _changeStageStatus(Map<String, dynamic> stage) async {
    final newStatus = (stage['status'] == StageStatus.paused.name)
        ? StageStatus.in_progress.name
        : StageStatus.paused.name;

    try {
      await _supabase
          .from('stages')
          .update({'status': newStatus})
          .eq('id', stage['id']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка изменения статуса: $e')),
      );
    }
  }
}