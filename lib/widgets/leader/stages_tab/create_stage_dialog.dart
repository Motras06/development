import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '/models/enums.dart';

class CreateStageDialog {
  static Future<void> show(
    BuildContext context, {
    required String projectId,
    Map<String, dynamic>? stageToEdit,
    VoidCallback? onSuccess,
  }) async {
    final supabase = Supabase.instance.client;
    final isEdit = stageToEdit != null;

    final nameController = TextEditingController(text: stageToEdit?['name'] ?? '');
    final descController = TextEditingController(text: stageToEdit?['description'] ?? '');

    DateTime? startDate = stageToEdit?['start_date'] != null
        ? DateTime.tryParse(stageToEdit!['start_date'])
        : null;
    DateTime? endDate = stageToEdit?['end_date'] != null
        ? DateTime.tryParse(stageToEdit!['end_date'])
        : null;

    List<Map<String, dynamic>> materialResources =
        List<Map<String, dynamic>>.from(stageToEdit?['material_resources'] ?? []);
    List<Map<String, dynamic>> nonMaterialResources =
        List<Map<String, dynamic>>.from(stageToEdit?['non_material_resources'] ?? []);

    bool _isUploading = false;

    // Загрузка файла
    Future<void> _pickAndUploadFile(StateSetter setDialogState) async {
      try {
        setDialogState(() => _isUploading = true);

        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) {
          setDialogState(() => _isUploading = false);
          return;
        }

        final file = result.files.single;
        final fileBytes = file.bytes ?? await File(file.path!).readAsBytes();
        final fileName = file.name;
        final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

        final path = 'stages/$projectId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

        await supabase.storage.from('files').uploadBinary(
              path,
              fileBytes,
              fileOptions: FileOptions(contentType: mimeType),
            );

        final publicUrl = supabase.storage.from('files').getPublicUrl(path);

        // Сохраняем в stage_documents (если редактируем — stage_id уже есть)
        final stageId = stageToEdit?['id'];
        if (stageId != null) {
          await supabase.from('stage_documents').insert({
            'stage_id': stageId,
            'name': fileName,
            'file_url': publicUrl,
            'mime_type': mimeType,
            'size': fileBytes.length,
            'uploaded_by': supabase.auth.currentUser?.id,
          });
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Файл загружен: $fileName')),
          );
        }

        setDialogState(() => _isUploading = false);
      } catch (e) {
        setDialogState(() => _isUploading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки файла: $e')),
          );
        }
      }
    }

    void addResource(bool isMaterial) {
      final nameCtrl = TextEditingController();
      final qtyCtrl = TextEditingController();
      final unitCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isMaterial ? 'Материальный ресурс' : 'Нематериальный ресурс'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название *'),
                ),
                if (isMaterial) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Количество'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(labelText: 'Единица измерения'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final resource = {
                  'name': nameCtrl.text.trim(),
                  if (isMaterial && qtyCtrl.text.isNotEmpty) 'quantity': double.tryParse(qtyCtrl.text) ?? 1,
                  if (isMaterial && unitCtrl.text.isNotEmpty) 'unit': unitCtrl.text.trim(),
                };
                (isMaterial ? materialResources : nonMaterialResources).add(resource);
                Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    isEdit ? 'Редактировать этап' : 'Новый этап',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Название
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Название этапа *',
                      prefixIcon: const Icon(Icons.title),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Описание
                  TextField(
                    controller: descController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Описание (опционально)',
                      prefixIcon: const Icon(Icons.description_outlined),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Даты
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            startDate == null ? 'Дата начала' : startDate!.toString().split(' ')[0],
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setDialogState(() => startDate = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: Text(
                            endDate == null ? 'Дата окончания' : endDate!.toString().split(' ')[0],
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setDialogState(() => endDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Ресурсы
                  Text(
                    'Ресурсы',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () => addResource(true),
                    icon: const Icon(Icons.add_box),
                    label: const Text('Добавить материал'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => addResource(false),
                    icon: const Icon(Icons.add_circle),
                    label: const Text('Добавить нематериальный ресурс'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Прикрепление файла
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : () => _pickAndUploadFile(setDialogState),
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_isUploading ? 'Загрузка...' : 'Прикрепить файл'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Кнопка сохранения
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: nameController.text.trim().isEmpty
                          ? null
                          : () async {
                              try {
                                final data = {
                                  'project_id': projectId,
                                  'name': nameController.text.trim(),
                                  'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                                  'start_date': startDate?.toIso8601String().split('T').first,
                                  'end_date': endDate?.toIso8601String().split('T').first,
                                  'status': StageStatus.planned.name,
                                  'material_resources': materialResources.isEmpty ? null : materialResources,
                                  'non_material_resources': nonMaterialResources.isEmpty ? null : nonMaterialResources,
                                };

                                if (isEdit) {
                                  await supabase
                                      .from('stages')
                                      .update(data)
                                      .eq('id', stageToEdit!['id']);
                                } else {
                                  await supabase.from('stages').insert(data);
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEdit ? 'Этап обновлён' : 'Этап создан'),
                                    ),
                                  );
                                  onSuccess?.call();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Ошибка: $e')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 10,
                      ),
                      child: Text(
                        isEdit ? 'Сохранить изменения' : 'Создать этап',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}