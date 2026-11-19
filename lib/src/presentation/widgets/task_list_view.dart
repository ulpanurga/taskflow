import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/components/helpers.dart';
import 'package:taskflow/components/state_views.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/presentation/bloc/data_state.dart';
import 'package:taskflow/src/presentation/bloc/tasks_cubit.dart';
import 'package:taskflow/src/presentation/bloc/users_cubit.dart';
import 'package:taskflow/src/presentation/pages/task_detail_page.dart';

/// Список задач с поиском, фильтрами, сортировкой и пагинацией.
/// Нужен TasksCubit выше по дереву.
class TaskListView extends StatefulWidget {
  final bool showAssigneeFilter;
  const TaskListView({super.key, this.showAssigneeFilter = true});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  final _searchCtrl = TextEditingController();
  late TaskFilterEntity _f;

  @override
  void initState() {
    super.initState();
    _f = context.read<TasksCubit>().filter;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Фильтр хранится и здесь (для выпадающих списков), и в Cubit.
  void _apply(TaskFilterEntity f) {
    setState(() => _f = f);
    context.read<TasksCubit>().setFilter(f);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Поиск по названию и описанию',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _f.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _apply(_f.copyWith(query: ''));
                      },
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _apply(_f.copyWith(query: v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<TaskStatus?>(
                value: _f.status,
                hint: const Text('Статус'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все статусы')),
                  for (final s in TaskStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.title)),
                ],
                onChanged: (v) => _apply(v == null
                    ? _f.copyWith(clearStatus: true)
                    : _f.copyWith(status: v)),
              ),
              DropdownButton<TaskPriority?>(
                value: _f.priority,
                hint: const Text('Приоритет'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Все приоритеты')),
                  for (final p in TaskPriority.values)
                    DropdownMenuItem(value: p, child: Text(p.title)),
                ],
                onChanged: (v) => _apply(v == null
                    ? _f.copyWith(clearPriority: true)
                    : _f.copyWith(priority: v)),
              ),
              if (widget.showAssigneeFilter) _assigneeFilter(),
              DropdownButton<TaskSort>(
                value: _f.sortBy,
                items: const [
                  DropdownMenuItem(
                      value: TaskSort.createdAt,
                      child: Text('По дате создания')),
                  DropdownMenuItem(
                      value: TaskSort.deadline, child: Text('По дедлайну')),
                ],
                onChanged: (v) => _apply(_f.copyWith(sortBy: v)),
              ),
              IconButton(
                tooltip: _f.ascending ? 'По возрастанию' : 'По убыванию',
                icon: Icon(
                    _f.ascending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () => _apply(_f.copyWith(ascending: !_f.ascending)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: DataStateView<TasksCubit, List<TaskEntity>>(
            emptyText: 'Задач нет',
            builder: (context, items) {
              final cubit = context.read<TasksCubit>();
              final hasMore = items.length >= cubit.limit;
              return ListView.builder(
                itemCount: items.length + (hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton(
                        onPressed: cubit.loadMore,
                        child: Text('Показать ещё (сейчас ${items.length})'),
                      ),
                    );
                  }
                  return TaskTile(task: items[i]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _assigneeFilter() {
    return BlocBuilder<UsersCubit, DataState<List<UserEntity>>>(
      builder: (context, state) {
        final users =
            state is DataSuccess<List<UserEntity>> ? state.data : const <UserEntity>[];
        return DropdownButton<int?>(
          value: users.any((u) => u.id == _f.assigneeId) ? _f.assigneeId : null,
          hint: const Text('Исполнитель'),
          items: [
            const DropdownMenuItem(
                value: null, child: Text('Все исполнители')),
            for (final u in users)
              DropdownMenuItem(value: u.id, child: Text(u.name)),
          ],
          onChanged: (v) => _apply(v == null
              ? _f.copyWith(clearAssignee: true)
              : _f.copyWith(assigneeId: v)),
        );
      },
    );
  }
}

class TaskTile extends StatelessWidget {
  final TaskEntity task;
  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue(DateTime.now());
    return ListTile(
      leading: Icon(Icons.flag, color: priorityColor(task.priority)),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${task.projectName} • ${task.assigneeName ?? 'не назначен'}'
        ' • до ${fmtDate(task.deadline)}${overdue ? ' (просрочена)' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: overdue ? const TextStyle(color: Colors.red) : null,
      ),
      trailing: StatusChip(task.status),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task.id)),
      ),
    );
  }
}
