import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../models/views.dart';
import '../../repositories/attachment_repository.dart';
import '../../repositories/comment_repository.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/task_repository.dart';
import '../../state/session_controller.dart';
import '../helpers.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    return StreamBuilder<TaskView?>(
      stream: repo.watchTask(taskId),
      builder: (context, snap) {
        final view = snap.data;
        if (snap.connectionState == ConnectionState.waiting && view == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (view == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Задача не найдена')),
          );
        }
        return _Body(view: view);
      },
    );
  }
}

class _Body extends StatelessWidget {
  final TaskView view;
  const _Body({required this.view});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    final session = context.read<SessionController>();
    final t = view.task;
    final inTrash = t.deletedAt != null;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.title, overflow: TextOverflow.ellipsis),
          actions: [
            if (!inTrash) ...[
              IconButton(
                tooltip: 'Отменить последнюю смену статуса',
                icon: const Icon(Icons.undo),
                onPressed: () => guard(context, () async {
                  final restored =
                      await repo.undoLastStatusChange(t.id, session.requireUser());
                  if (context.mounted) {
                    showMessage(context, 'Статус возвращён: ${restored.title}');
                  }
                }),
              ),
              IconButton(
                tooltip: 'Изменить',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskFormScreen(task: view)),
                ),
              ),
              IconButton(
                tooltip: 'В корзину',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(context, 'Переместить задачу в корзину?') &&
                      context.mounted) {
                    final ok = await guard(context, () => repo.softDelete(t.id));
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
            _Details(view: view, readOnly: inTrash),
            _CommentsTab(taskId: t.id),
            _HistoryTab(taskId: t.id),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final TaskView view;
  final bool readOnly;
  const _Details({required this.view, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    final session = context.read<SessionController>();
    final t = view.task;

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
        Text(t.description.isEmpty ? 'Без описания' : t.description),
        const SizedBox(height: 12),
        Text('Проект: ${view.project.name}'),
        Text('Создана: ${fmtDateTime(t.createdAt)}'),
        Text('Изменена: ${fmtDateTime(t.updatedAt)}'),
        Text('Дедлайн: ${fmtDate(t.deadline)}'),
        const Divider(height: 28),
        const Text('Статус'),
        DropdownButton<TaskStatus>(
          value: t.status,
          isExpanded: true,
          items: [
            for (final s in TaskStatus.values)
              DropdownMenuItem(value: s, child: Text(s.title)),
          ],
          onChanged: readOnly
              ? null
              : (s) {
                  if (s != null) {
                    guard(context,
                        () => repo.changeStatus(t.id, s, session.requireUser()));
                  }
                },
        ),
        const SizedBox(height: 8),
        const Text('Приоритет'),
        DropdownButton<TaskPriority>(
          value: t.priority,
          isExpanded: true,
          items: [
            for (final p in TaskPriority.values)
              DropdownMenuItem(value: p, child: Text(p.title)),
          ],
          onChanged: readOnly
              ? null
              : (p) {
                  if (p != null) {
                    guard(context, () => repo.changePriority(t.id, p));
                  }
                },
        ),
        const SizedBox(height: 8),
        const Text('Исполнитель'),
        _AssigneePicker(view: view, readOnly: readOnly),
        const Divider(height: 28),
        _AttachmentsSection(taskId: t.id, readOnly: readOnly),
      ],
    );
  }
}

class _AssigneePicker extends StatelessWidget {
  final TaskView view;
  final bool readOnly;
  const _AssigneePicker({required this.view, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final projects = context.read<ProjectRepository>();
    final repo = context.read<TaskRepository>();
    final session = context.read<SessionController>();
    return FutureBuilder<List<User>>(
      future: projects.getMembers(view.task.projectId),
      builder: (context, snap) {
        final members = snap.data ?? const <User>[];
        final current = view.task.assigneeId;
        return DropdownButton<int?>(
          value: members.any((u) => u.id == current) ? current : null,
          isExpanded: true,
          hint: const Text('Не назначен'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Не назначен')),
            for (final u in members)
              DropdownMenuItem(value: u.id, child: Text(u.name)),
          ],
          onChanged: readOnly
              ? null
              : (id) => guard(context,
                  () => repo.reassign(view.task.id, id, session.requireUser())),
        );
      },
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  final int taskId;
  final bool readOnly;
  const _AttachmentsSection({required this.taskId, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AttachmentRepository>();
    return StreamBuilder<List<Attachment>>(
      stream: repo.watchForTask(taskId),
      builder: (context, snap) {
        final items = snap.data ?? const <Attachment>[];
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
                      final dynamic res = await FilePicker.pickFiles();
                      final dynamic file = res == null
                          ? null
                          : (res is List ? (res.isEmpty ? null : res.first) : res.files.first);
                      final String? path = file?.path as String?;                      if (file == null || path == null || !context.mounted) {
                        return;
                      }
                      await guard(
                          context, () => repo.add(taskId, file.name, path));
                    },
                  ),
              ],
            ),
            if (items.isEmpty) const Text('Файлов нет'),
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
                        onPressed: () => repo.delete(a.id),
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _CommentsTab extends StatefulWidget {
  final int taskId;
  const _CommentsTab({required this.taskId});

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
    final repo = context.read<CommentRepository>();
    final session = context.read<SessionController>();
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<CommentView>>(
            stream: repo.watchForTask(widget.taskId),
            builder: (context, snap) {
              final items = snap.data ?? const <CommentView>[];
              if (items.isEmpty) {
                return const Center(child: Text('Комментариев нет'));
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final c = items[i];
                  return ListTile(
                    title: Text(c.comment.body),
                    subtitle:
                        Text('${c.author.name} • ${fmtDateTime(c.comment.createdAt)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => guard(context,
                          () => repo.delete(c.comment.id, session.requireUser())),
                    ),
                  );
                },
              );
            },
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
                    final ok = await guard(
                        context,
                        () => repo.add(
                            widget.taskId, session.requireUser(), _ctrl.text));
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
  final int taskId;
  const _HistoryTab({required this.taskId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    return StreamBuilder<List<HistoryView>>(
      stream: repo.watchHistory(taskId),
      builder: (context, snap) {
        final items = snap.data ?? const <HistoryView>[];
        if (items.isEmpty) return const Center(child: Text('История пуста'));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final h = items[i].entry;
            final who = items[i].user?.name ?? 'неизвестно';
            final change = h.action == HistoryAction.statusChanged ||
                    h.action == HistoryAction.undo
                ? '${h.oldStatus?.title ?? '—'} → ${h.newStatus.title}'
                : (h.note ?? '');
            return ListTile(
              leading: Icon(
                h.isUndone ? Icons.history_toggle_off : Icons.history,
              ),
              title: Text('${h.action.title}: $change',
                  style: h.isUndone
                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                      : null),
              subtitle: Text('$who • ${fmtDateTime(h.changedAt)}'),
            );
          },
        );
      },
    );
  }
}
