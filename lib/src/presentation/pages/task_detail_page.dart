import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/components/file_picking.dart';
import 'package:taskflow/components/helpers.dart';
import 'package:taskflow/components/state_views.dart';
import 'package:taskflow/core/di/injection.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/presentation/bloc/attachments_cubit.dart';
import 'package:taskflow/src/presentation/bloc/comments_cubit.dart';
import 'package:taskflow/src/presentation/bloc/data_state.dart';
import 'package:taskflow/src/presentation/bloc/task_detail_cubit.dart';
import 'package:taskflow/src/presentation/bloc/task_history_cubit.dart';
import 'package:taskflow/src/presentation/pages/task_form_page.dart';

class TaskDetailPage extends StatelessWidget {
  final int taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) => getIt<TaskDetailCubit>(param1: taskId)..load()),
        BlocProvider(
            create: (_) => getIt<CommentsCubit>(param1: taskId)..load()),
        BlocProvider(
            create: (_) => getIt<TaskHistoryCubit>(param1: taskId)..load()),
        BlocProvider(
            create: (_) => getIt<AttachmentsCubit>(param1: taskId)..load()),
      ],
      child: BlocBuilder<TaskDetailCubit, DataState<TaskEntity?>>(
        builder: (context, state) {
          if (state is DataSuccess<TaskEntity?> && state.data != null) {
            return _Body(task: state.data!);
          }
          // Загрузка, ошибка или «задача не найдена»
          return Scaffold(
            appBar: AppBar(),
            body: state is DataError<TaskEntity?>
                ? ErrorView(
                    failure: state.failure,
                    onRetry: () => context.read<TaskDetailCubit>().retry(),
                  )
                : state is DataEmpty<TaskEntity?>
                    ? const EmptyView(text: 'Задача не найдена')
                    : const LoadingView(),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final TaskEntity task;
  const _Body({required this.task});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaskDetailCubit>();
    final inTrash = task.isDeleted;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(task.title, overflow: TextOverflow.ellipsis),
          actions: [
            if (!inTrash) ...[
              IconButton(
                tooltip: 'Отменить последнюю смену статуса',
                icon: const Icon(Icons.undo),
                onPressed: () async {
                  final result = await cubit.undo();
                  if (!context.mounted) return;
                  result.fold(
                    (f) => showMessage(context, f.message),
                    (s) => showMessage(context, 'Статус возвращён: ${s.title}'),
                  );
                },
              ),
              IconButton(
                tooltip: 'Изменить',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskFormPage(task: task)),
                ),
              ),
              IconButton(
                tooltip: 'В корзину',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(context, 'Переместить задачу в корзину?') &&
                      context.mounted) {
                    final ok = await handle(context, cubit.moveToTrash());
                    if (ok && context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Детали'),
            Tab(text: 'Комментарии'),
            Tab(text: 'История'),
          ]),
        ),
        body: TabBarView(
          children: [
            _Details(task: task, readOnly: inTrash),
            const _CommentsTab(),
            const _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final TaskEntity task;
  final bool readOnly;
  const _Details({required this.task, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaskDetailCubit>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (readOnly)
          const Card(
            color: Color(0xFFFFEBEE),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Задача в корзине'),
            ),
          ),
        Text(task.description.isEmpty ? 'Без описания' : task.description),
        const SizedBox(height: 12),
        Text('Проект: ${task.projectName}'),
        Text('Создана: ${fmtDateTime(task.createdAt)}'),
        Text('Изменена: ${fmtDateTime(task.updatedAt)}'),
        Text('Дедлайн: ${fmtDate(task.deadline)}'),
        const Divider(height: 28),
        const Text('Статус'),
        DropdownButton<TaskStatus>(
          value: task.status,
          isExpanded: true,
          items: [
            for (final s in TaskStatus.values)
              DropdownMenuItem(value: s, child: Text(s.title)),
          ],
          onChanged: readOnly
              ? null
              : (s) {
                  if (s != null) handle(context, cubit.changeStatus(s));
                },
        ),
        const SizedBox(height: 8),
        const Text('Приоритет'),
        DropdownButton<TaskPriority>(
          value: task.priority,
          isExpanded: true,
          items: [
            for (final p in TaskPriority.values)
              DropdownMenuItem(value: p, child: Text(p.title)),
          ],
          onChanged: readOnly
              ? null
              : (p) {
                  if (p != null) handle(context, cubit.changePriority(p));
                },
        ),
        const SizedBox(height: 8),
        const Text('Исполнитель'),
        _AssigneePicker(task: task, readOnly: readOnly),
        const Divider(height: 28),
        _AttachmentsSection(readOnly: readOnly),
      ],
    );
  }
}

/// Список участников загружается один раз, а не при каждой перерисовке.
class _AssigneePicker extends StatefulWidget {
  final TaskEntity task;
  final bool readOnly;
  const _AssigneePicker({required this.task, required this.readOnly});

  @override
  State<_AssigneePicker> createState() => _AssigneePickerState();
}

class _AssigneePickerState extends State<_AssigneePicker> {
  List<UserEntity> _members = const [];

  @override
  void initState() {
    super.initState();
    context
        .read<TaskDetailCubit>()
        .loadMembers(widget.task.projectId)
        .then((list) {
      if (mounted) setState(() => _members = list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.task.assigneeId;
    return DropdownButton<int?>(
      value: _members.any((u) => u.id == current) ? current : null,
      isExpanded: true,
      hint: const Text('Не назначен'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Не назначен')),
        for (final u in _members)
          DropdownMenuItem(value: u.id, child: Text(u.name)),
      ],
      onChanged: widget.readOnly
          ? null
          : (id) =>
              handle(context, context.read<TaskDetailCubit>().reassign(id)),
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  final bool readOnly;
  const _AttachmentsSection({required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AttachmentsCubit>();
    return BlocBuilder<AttachmentsCubit, DataState<List<AttachmentEntity>>>(
      builder: (context, state) {
        final items = state is DataSuccess<List<AttachmentEntity>>
            ? state.data
            : const <AttachmentEntity>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                    child: Text('Вложения',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                if (!readOnly)
                  TextButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Добавить'),
                    onPressed: () async {
                      final file = await pickLocalFile();
                      if (file == null || !context.mounted) return;
                      await handle(context, cubit.add(file.name, file.path));
                    },
                  ),
              ],
            ),
            if (state is DataError<List<AttachmentEntity>>)
              Text(state.failure.message),
            if (items.isEmpty && state is! DataError) const Text('Файлов нет'),
            for (final a in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file),
                title: Text(a.fileName),
                subtitle: Text('${a.filePath}\n${fmtDateTime(a.addedAt)}'),
                isThreeLine: true,
                trailing: readOnly
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => handle(context, cubit.delete(a.id)),
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _CommentsTab extends StatefulWidget {
  const _CommentsTab();

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: DataStateView<CommentsCubit, List<CommentEntity>>(
            emptyText: 'Комментариев нет',
            builder: (context, items) => ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final c = items[i];
                return ListTile(
                  title: Text(c.body),
                  subtitle: Text('${c.authorName} • ${fmtDateTime(c.createdAt)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => handle(
                        context, context.read<CommentsCubit>().delete(c.id)),
                  ),
                );
              },
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                        hintText: 'Новый комментарий',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final ok = await handle(context,
                        context.read<CommentsCubit>().add(_ctrl.text));
                    if (ok) _ctrl.clear();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return DataStateView<TaskHistoryCubit, List<HistoryEntryEntity>>(
      emptyText: 'История пуста',
      builder: (context, items) => ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final h = items[i];
          final who = h.changedByName ?? 'неизвестно';
          final change = h.action == HistoryAction.statusChanged ||
                  h.action == HistoryAction.undo
              ? '${h.oldStatus?.title ?? '—'} → ${h.newStatus.title}'
              : (h.note ?? '');
          return ListTile(
            leading:
                Icon(h.isUndone ? Icons.history_toggle_off : Icons.history),
            title: Text('${h.action.title}: $change',
                style: h.isUndone
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null),
            subtitle: Text('$who • ${fmtDateTime(h.changedAt)}'),
          );
        },
      ),
    );
  }
}
