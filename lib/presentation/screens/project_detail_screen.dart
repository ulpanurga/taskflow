import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../models/views.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/user_repository.dart';
import '../../state/tasks_controller.dart';
import '../helpers.dart';
import '../widgets/task_list_view.dart';
import 'task_form_screen.dart';

/// Проект: вкладки «Задачи» и «Участники».
class ProjectDetailScreen extends StatelessWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => TasksController(c.read<TaskRepository>(),
          initial: TaskFilter(projectId: projectId)),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Проект'),
            bottom: const TabBar(tabs: [
              Tab(text: 'Задачи'),
              Tab(text: 'Участники'),
            ]),
          ),
          body: TabBarView(
            children: [
              const TaskListView(),
              _MembersTab(projectId: projectId),
            ],
          ),
          floatingActionButton: Builder(
            builder: (ctx) => FloatingActionButton(
              onPressed: () {
                final tab = DefaultTabController.of(ctx).index;
                if (tab == 0) {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => TaskFormScreen(projectId: projectId)),
                  );
                } else {
                  _addMember(ctx, projectId);
                }
              },
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _addMember(BuildContext context, int projectId) async {
    final projects = context.read<ProjectRepository>();
    final users = await context.read<UserRepository>().getAll();
    final members = await projects.getMembers(projectId);
    final memberIds = members.map((m) => m.id).toSet();
    final candidates = users.where((u) => !memberIds.contains(u.id)).toList();
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      showMessage(context, 'Нет пользователей, которых можно добавить');
      return;
    }

    User? chosen = candidates.first;
    var role = MemberRole.member;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Добавить участника'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<User>(
                value: chosen,
                isExpanded: true,
                items: [
                  for (final u in candidates)
                    DropdownMenuItem(value: u, child: Text(u.name)),
                ],
                onChanged: (v) => setState(() => chosen = v),
              ),
              DropdownButton<MemberRole>(
                value: role,
                isExpanded: true,
                items: [
                  for (final r in MemberRole.values)
                    DropdownMenuItem(value: r, child: Text(r.title)),
                ],
                onChanged: (v) => setState(() => role = v ?? role),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Добавить')),
          ],
        ),
      ),
    );
    if (ok == true && chosen != null && context.mounted) {
      await guard(
          context, () => projects.addMember(projectId, chosen!.id, role: role));
    }
  }
}

class _MembersTab extends StatelessWidget {
  final int projectId;
  const _MembersTab({required this.projectId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProjectRepository>();
    return StreamBuilder<List<MemberView>>(
      stream: repo.watchMembers(projectId),
      builder: (context, snap) {
        final items = snap.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const Center(child: Text('В проекте пока нет участников'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final m = items[i];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(m.user.name),
              subtitle: Text(m.user.email),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<MemberRole>(
                    value: m.member.role,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final r in MemberRole.values)
                        DropdownMenuItem(value: r, child: Text(r.title)),
                    ],
                    onChanged: (r) {
                      if (r != null) {
                        repo.setRole(projectId, m.user.id, r);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Убрать из проекта',
                    icon: const Icon(Icons.person_remove),
                    onPressed: () =>
                        guard(context, () => repo.removeMember(projectId, m.user.id)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
