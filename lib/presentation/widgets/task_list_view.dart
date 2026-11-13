import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../models/views.dart';
import '../../repositories/user_repository.dart';
import '../../state/tasks_controller.dart';
import '../helpers.dart';
import '../screens/task_detail_screen.dart';

/// Список задач с поиском, фильтрами, сортировкой и пагинацией.
/// Нужен TasksController выше по дереву (Provider).
class TaskListView extends StatefulWidget {
  /// Показывать ли фильтр по исполнителю
  final bool showAssigneeFilter;
  const TaskListView({super.key, this.showAssigneeFilter = true});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TasksController>();
    final f = ctrl.filter;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Поиск по названию и описанию',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: f.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        ctrl.update(f.copyWith(query: ''));
                      },
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => ctrl.update(f.copyWith(query: v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<TaskStatus?>(
                value: f.status,
                hint: const Text('Статус'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все статусы')),
                  for (final s in TaskStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.title)),
                ],
                onChanged: (v) => ctrl.update(v == null
                    ? f.copyWith(clearStatus: true)
                    : f.copyWith(status: v)),
              ),
              DropdownButton<TaskPriority?>(
                value: f.priority,
                hint: const Text('Приоритет'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Все приоритеты')),
                  for (final p in TaskPriority.values)
                    DropdownMenuItem(value: p, child: Text(p.title)),
                ],
                onChanged: (v) => ctrl.update(v == null
                    ? f.copyWith(clearPriority: true)
                    : f.copyWith(priority: v)),
              ),
              if (widget.showAssigneeFilter)
                StreamBuilder<List<User>>(
                  stream: context.read<UserRepository>().watchAll(),
                  builder: (context, snap) {
                    final users = snap.data ?? const <User>[];
                    return DropdownButton<int?>(
                      value: users.any((u) => u.id == f.assigneeId)
                          ? f.assigneeId
                          : null,
                      hint: const Text('Исполнитель'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Все исполнители')),
                        for (final u in users)
                          DropdownMenuItem(value: u.id, child: Text(u.name)),
                      ],
                      onChanged: (v) => ctrl.update(v == null
                          ? f.copyWith(clearAssignee: true)
                          : f.copyWith(assigneeId: v)),
                    );
                  },
                ),
              DropdownButton<TaskSort>(
                value: f.sortBy,
                items: const [
                  DropdownMenuItem(
                      value: TaskSort.createdAt,
                      child: Text('По дате создания')),
                  DropdownMenuItem(
                      value: TaskSort.deadline, child: Text('По дедлайну')),
                ],
                onChanged: (v) => ctrl.update(f.copyWith(sortBy: v)),
              ),
              IconButton(
                tooltip: f.ascending ? 'По возрастанию' : 'По убыванию',
                icon: Icon(
                    f.ascending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () => ctrl.update(f.copyWith(ascending: !f.ascending)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<TaskView>>(
            stream: ctrl.stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Ошибка: ${snap.error}'));
              }
              final items = snap.data;
              if (items == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return const Center(child: Text('Задач нет'));
              }
              final hasMore = items.length >= ctrl.limit;
              return ListView.builder(
                itemCount: items.length + (hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton(
                        onPressed: ctrl.loadMore,
                        child: Text('Показать ещё (сейчас ${items.length})'),
                      ),
                    );
                  }
                  return TaskTile(view: items[i]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class TaskTile extends StatelessWidget {
  final TaskView view;
  const TaskTile({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final t = view.task;
    final overdue = t.deadline != null &&
        t.status.isOpen &&
        t.deadline!.isBefore(DateTime.now());
    return ListTile(
      leading: Icon(Icons.flag, color: priorityColor(t.priority)),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${view.project.name} • ${view.assignee?.name ?? 'не назначен'}'
        ' • до ${fmtDate(t.deadline)}${overdue ? ' (просрочена)' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: overdue ? const TextStyle(color: Colors.red) : null,
      ),
      trailing: StatusChip(t.status),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
      ),
    );
  }
}
