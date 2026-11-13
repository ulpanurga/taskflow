import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/views.dart';
import '../../repositories/task_repository.dart';
import '../../state/session_controller.dart';
import '../helpers.dart';

/// Корзина: просмотр, восстановление и полное удаление задач.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    final session = context.read<SessionController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Корзина')),
      body: StreamBuilder<List<TaskView>>(
        stream: repo.watchTasks(const TaskFilter(onlyDeleted: true, limit: 500)),
        builder: (context, snap) {
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('Корзина пуста'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final t = items[i].task;
              return ListTile(
                title: Text(t.title),
                subtitle: Text(
                    '${items[i].project.name} • удалена ${fmtDateTime(t.deletedAt!)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Восстановить',
                      icon: const Icon(Icons.restore),
                      onPressed: () => guard(context,
                          () => repo.restore(t.id, session.requireUser())),
                    ),
                    IconButton(
                      tooltip: 'Удалить навсегда',
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () async {
                        if (await confirm(
                            context, 'Удалить задачу навсегда?')) {
                          if (context.mounted) {
                            await guard(
                                context, () => repo.deletePermanently(t.id));
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
