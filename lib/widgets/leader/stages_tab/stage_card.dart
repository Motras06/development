import 'package:flutter/material.dart';
import '/models/enums.dart';

class StageCard extends StatelessWidget {
  final Map<String, dynamic> stage;

  const StageCard({super.key, required this.stage});

  @override
  Widget build(BuildContext context) {

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

    final statusColor = _getStageStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          radius: 20,
          child: Text(status.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('${start ?? '?'} — ${end ?? '?'}', style: const TextStyle(fontSize: 12)),
        children: [
          if (description != null && description.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(description)),
          const SizedBox(height: 8),
          if (material != null && material.isNotEmpty) _buildResources('Материальные ресурсы', material),
          if (nonMaterial != null && nonMaterial.isNotEmpty) _buildResources('Нематериальные ресурсы', nonMaterial),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () {}, child: const Text('Редактировать')),
              TextButton(onPressed: () {}, child: const Text('Приостановить')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResources(String title, List<dynamic> resources) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ...resources.map((res) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• ${res['name']} ${res['quantity'] != null ? "— ${res['quantity']} ${res['unit'] ?? ''}" : ""}'),
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
}