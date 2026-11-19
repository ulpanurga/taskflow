import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/components/helpers.dart';
import 'package:taskflow/components/state_views.dart';
import 'package:taskflow/core/di/injection.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/presentation/bloc/trash_cubit.dart';

/// Корзина: восстановление и полное удаление задач.
class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TrashCubit>()..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Корзина')),
        body: DataStateView<TrashCubit, List<TaskEntity>>(
          emptyText: 'Корзина пуста',
          builder: (context, items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final t = items[i];
              final cubit = context.read<TrashCubit>();
              return ListTile(
                title: Text(t.title),
                subtitle: Text(
                    '${t.projectName} • удалена ${fmtDateTime(t.deletedAt!)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Восстановить',
                      icon: const Icon(Icons.restore),
                      onPressed: () => handle(context, cubit.restore(t.id)),
                    ),
                    IconButton(
                      tooltip: 'Удалить навсегда',
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () async {
                        if (await confirm(
                                context, 'Удалить задачу навсегда?') &&
                            context.mounted) {
                          await handle(context, cubit.deleteForever(t.id));
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
