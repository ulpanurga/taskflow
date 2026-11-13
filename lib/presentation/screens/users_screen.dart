import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/views.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/user_repository.dart';
import '../../state/session_controller.dart';
import '../../state/tasks_controller.dart';
import '../helpers.dart';
import '../widgets/task_list_view.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  Future<void> _openForm(BuildContext context, {User? user}) async {
    final repo = context.read<UserRepository>();
    final session = context.read<SessionController>();
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

    await guard(context, () async {
      if (user == null) {
        final id = await repo.create(nameCtrl.text, emailCtrl.text);
        // Первый созданный пользователь становится текущим.
        if (session.userId == null) session.setUser(id);
      } else {
        await repo.update(user.id, nameCtrl.text, emailCtrl.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<UserRepository>();
    final session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Пользователи')),
      body: StreamBuilder<List<User>>(
        stream: repo.watchAll(),
        builder: (context, snap) {
          final users = snap.data;
          if (users == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (users.isEmpty) {
            return const Center(child: Text('Добавьте первого пользователя'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              final isMe = session.userId == u.id;
              return ListTile(
                leading: CircleAvatar(
                    child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase())),
                title: Text(u.name),
                subtitle: Text(
                    '${u.email} • с ${fmtDate(u.registeredAt)}${isMe ? ' • ТЕКУЩИЙ' : ''}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserTasksScreen(user: u)),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'me') {
                      session.setUser(u.id);
                    } else if (v == 'edit') {
                      await _openForm(context, user: u);
                    } else if (v == 'delete') {
                      if (await confirm(context, 'Удалить ${u.name}?') &&
                          context.mounted) {
                        final ok = await guard(context, () => repo.delete(u.id));
                        if (ok && session.userId == u.id) session.setUser(null);
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
class UserTasksScreen extends StatelessWidget {
  final User user;
  const UserTasksScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => TasksController(c.read<TaskRepository>(),
          initial: TaskFilter(assigneeId: user.id)),
      child: Scaffold(
        appBar: AppBar(title: Text('Задачи: ${user.name}')),
        body: const TaskListView(showAssigneeFilter: false),
      ),
    );
  }
}
