import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../models/views.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/task_repository.dart';
import '../../state/session_controller.dart';
import '../helpers.dart';

/// Создание и редактирование задачи.
/// Если передан [task] — редактирование, иначе создание.
class TaskFormScreen extends StatefulWidget {
  final int? projectId;
  final TaskView? task;
  const TaskFormScreen({super.key, this.projectId, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<Project> _projects = [];
  List<User> _members = [];
  int? _projectId;
  int? _assigneeId;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _deadline;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task?.task;
    if (t != null) {
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description;
      _projectId = t.projectId;
      _assigneeId = t.assigneeId;
      _priority = t.priority;
      _deadline = t.deadline;
    } else {
      _projectId = widget.projectId;
    }
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ProjectRepository>();
    final projects = await repo.getAll();
    final members =
        _projectId == null ? <User>[] : await repo.getMembers(_projectId!);
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _members = members;
    });
  }

  Future<void> _onProjectChanged(int? id) async {
    final members =
        id == null ? <User>[] : await context.read<ProjectRepository>().getMembers(id);
    if (!mounted) return;
    setState(() {
      _projectId = id;
      _members = members;
      _assigneeId = null;
    });
  }

  Future<void> _pickDeadline() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _deadline = d);
  }

  Future<void> _save() async {
    final repo = context.read<TaskRepository>();
    final session = context.read<SessionController>();
    final ok = await guard(context, () async {
      final actor = session.requireUser();
      if (_editing) {
        final old = widget.task!.task;
        await repo.updateTask(
          old.id,
          title: _titleCtrl.text,
          description: _descCtrl.text,
          priority: _priority,
          deadline: _deadline,
        );
        if (_assigneeId != old.assigneeId) {
          await repo.reassign(old.id, _assigneeId, actor);
        }
      } else {
        await repo.createTask(
          projectId: _projectId,
          title: _titleCtrl.text,
          description: _descCtrl.text,
          assigneeId: _assigneeId,
          priority: _priority,
          deadline: _deadline,
          actorId: actor,
        );
      }
    });
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Редактирование задачи' : 'Новая задача')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Описание'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _projects.any((p) => p.id == _projectId) ? _projectId : null,
            decoration: const InputDecoration(labelText: 'Проект'),
            items: [
              for (final p in _projects)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: _editing ? null : _onProjectChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _members.any((u) => u.id == _assigneeId) ? _assigneeId : null,
            decoration: const InputDecoration(
                labelText: 'Исполнитель (только участники проекта)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Не назначен')),
              for (final u in _members)
                DropdownMenuItem(value: u.id, child: Text(u.name)),
            ],
            onChanged: (v) => setState(() => _assigneeId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskPriority>(
            value: _priority,
            decoration: const InputDecoration(labelText: 'Приоритет'),
            items: [
              for (final p in TaskPriority.values)
                DropdownMenuItem(value: p, child: Text(p.title)),
            ],
            onChanged: (v) => setState(() => _priority = v ?? _priority),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Дедлайн: ${fmtDate(_deadline)}')),
              TextButton(onPressed: _pickDeadline, child: const Text('Выбрать')),
              if (_deadline != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _deadline = null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
    );
  }
}
