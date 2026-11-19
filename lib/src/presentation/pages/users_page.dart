import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/components/helpers.dart';
import 'package:taskflow/components/state_views.dart';
import 'package:taskflow/core/di/injection.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';
import 'package:taskflow/src/presentation/bloc/tasks_cubit.dart';
import 'package:taskflow/src/presentation/bloc/users_cubit.dart';
import 'package:taskflow/src/presentation/widgets/task_list_view.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  Future<void> _openForm(BuildContext context, {UserEntity? user}) async {
    final cubit = context.read<UsersCubit>();
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user == null ? 'Новый пользователь' : 'Редактирование'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Имя')),
            TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
          ],
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
    );
    if (ok != true || !context.mounted) return;

    await handle(
      context,
      user == null
          ? cubit.create(nameCtrl.text, emailCtrl.text)
          : cubit.update(user.id, nameCtrl.text, emailCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пользователи')),
      body: DataStateView<UsersCubit, List<UserEntity>>(
        emptyText: 'Добавьте первого пользователя',
        builder: (context, users) {
          final currentId = context.watch<SessionCubit>().state;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              final isMe = currentId == u.id;
              return ListTile(
                leading: CircleAvatar(
                    child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase())),
                title: Text(u.name),
                subtitle: Text(
                    '${u.email} • с ${fmtDate(u.registeredAt)}${isMe ? ' • ТЕКУЩИЙ' : ''}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserTasksPage(user: u)),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    final cubit = context.read<UsersCubit>();
                    if (v == 'me') {
                      cubit.makeCurrent(u.id);
                    } else if (v == 'edit') {
                      await _openForm(context, user: u);
                    } else if (v == 'delete') {
                      if (await confirm(context, 'Удалить ${u.name}?') &&
                          context.mounted) {
                        await handle(context, cubit.delete(u.id));
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'me', child: Text('Сделать текущим')),
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
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

/// Задачи конкретного пользователя.
class UserTasksPage extends StatelessWidget {
  final UserEntity user;
  const UserTasksPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TasksCubit>(
          param1: TaskFilterEntity(assigneeId: user.id))
        ..load(),
      child: Scaffold(
        appBar: AppBar(title: Text('Задачи: ${user.name}')),
        body: const TaskListView(showAssigneeFilter: false),
      ),
    );
  }
}
