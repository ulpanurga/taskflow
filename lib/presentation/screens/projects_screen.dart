import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../repositories/project_repository.dart';
import '../helpers.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  Future<void> _openForm(BuildContext context, {Project? project}) async {
    final repo = context.read<ProjectRepository>();
    final nameCtrl = TextEditingController(text: project?.name ?? '');
    final descCtrl = TextEditingController(text: project?.description ?? '');
    var status = project?.status ?? ProjectStatus.active;
    DateTime? finishedAt = project?.finishedAt;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(project == null ? 'Новый проект' : 'Редактирование'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Название')),
                TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Описание')),
                const SizedBox(height: 8),
                DropdownButton<ProjectStatus>(
                  value: status,
                  isExpanded: true,
                  items: [
                    for (final s in ProjectStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.title)),
                  ],
                  onChanged: (v) => setState(() => status = v ?? status),
                ),
                Row(
                  children: [
                    Expanded(
                        child: Text('Дата завершения: ${fmtDate(finishedAt)}')),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: finishedAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => finishedAt = d);
                      },
                      child: const Text('Выбрать'),
                    ),
                    if (finishedAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => finishedAt = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    await guard(context, () async {
      if (project == null) {
        await repo.create(
          name: nameCtrl.text,
          description: descCtrl.text,
          status: status,
          finishedAt: finishedAt,
        );
      } else {
        await repo.update(
          project.id,
          name: nameCtrl.text,
          description: descCtrl.text,
          status: status,
          finishedAt: finishedAt,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProjectRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Проекты')),
      body: StreamBuilder<List<Project>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('Проектов пока нет'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final p = items[i];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(p.name),
                subtitle: Text(
                    '${p.status.title} • создан ${fmtDate(p.createdAt)}'
                    '${p.finishedAt != null ? ' • до ${fmtDate(p.finishedAt)}' : ''}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProjectDetailScreen(projectId: p.id)),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await _openForm(context, project: p);
                    } else if (v == 'delete') {
                      if (await confirm(context,
                              'Удалить проект «${p.name}» вместе со всеми задачами?') &&
                          context.mounted) {
                        await guard(context, () => repo.delete(p.id));
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Изменить')),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }
}
