import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/components/helpers.dart';
import 'package:taskflow/components/state_views.dart';
import 'package:taskflow/core/di/injection.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/presentation/bloc/project_members_cubit.dart';
import 'package:taskflow/src/presentation/bloc/tasks_cubit.dart';
import 'package:taskflow/src/presentation/pages/import_page.dart';
import 'package:taskflow/src/presentation/pages/task_form_page.dart';
import 'package:taskflow/src/presentation/widgets/task_list_view.dart';

/// Проект: вкладки «Задачи» и «Участники».
class ProjectDetailPage extends StatelessWidget {
  final int projectId;
  final String name;
  const ProjectDetailPage(
      {super.key, required this.projectId, required this.name});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<TasksCubit>(
              param1: TaskFilterEntity(projectId: projectId))
            ..load(),
        ),
        BlocProvider(
          create: (_) =>
              getIt<ProjectMembersCubit>(param1: projectId)..load(),
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Импорт задач с сервера',
                icon: const Icon(Icons.cloud_download_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ImportPage(projectId: projectId)),
                ),
              ),
            ],
            bottom: const TabBar(tabs: [
              Tab(text: 'Задачи'),
              Tab(text: 'Участники'),
            ]),
          ),
          body: const TabBarView(
            children: [
              TaskListView(),
              _MembersTab(),
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
                        builder: (_) => TaskFormPage(projectId: projectId)),
                  );
                } else {
                  _addMember(ctx);
                }
              },
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _addMember(BuildContext context) async {
    final cubit = context.read<ProjectMembersCubit>();
    final candidates = await cubit.candidates();
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      showMessage(context, 'Нет пользователей, которых можно добавить');
      return;
    }

    UserEntity? chosen = candidates.first;
    var role = MemberRole.member;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Добавить участника'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<UserEntity>(
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
    final user = chosen;
    if (ok == true && user != null && context.mounted) {
      await handle(context, cubit.add(user.id, role));
    }
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context) {
    return DataStateView<ProjectMembersCubit, List<MemberEntity>>(
      emptyText: 'В проекте пока нет участников',
      builder: (context, items) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final m = items[i];
          final cubit = context.read<ProjectMembersCubit>();
          return ListTile(
            leading: const Icon(Icons.person),
            title: Text(m.userName),
            subtitle: Text(m.userEmail),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<MemberRole>(
                  value: m.role,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final r in MemberRole.values)
                      DropdownMenuItem(value: r, child: Text(r.title)),
                  ],
                  onChanged: (r) {
                    if (r != null) {
                      handle(context, cubit.setRole(m.userId, r));
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Убрать из проекта',
                  icon: const Icon(Icons.person_remove),
                  onPressed: () => handle(context, cubit.remove(m.userId)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
