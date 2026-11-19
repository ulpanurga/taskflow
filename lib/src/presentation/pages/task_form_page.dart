import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/components/helpers.dart';
import 'package:taskflow/components/state_views.dart';
import 'package:taskflow/core/di/injection.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/presentation/bloc/task_form_cubit.dart';

/// Создание и редактирование задачи.
/// Если передан [task] — редактирование, иначе создание.
class TaskFormPage extends StatelessWidget {
  final int? projectId;
  final TaskEntity? task;
  const TaskFormPage({super.key, this.projectId, this.task});

  @override
  Widget build(BuildContext context) {
    final initialProject = task?.projectId ?? projectId;
    return BlocProvider(
      create: (_) => getIt<TaskFormCubit>()..init(projectId: initialProject),
      child: _TaskForm(
          task: task, initialProjectId: initialProject),
    );
  }
}

class _TaskForm extends StatefulWidget {
  final TaskEntity? task;
  final int? initialProjectId;
  const _TaskForm({required this.task, required this.initialProjectId});

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _projectId;
  int? _assigneeId;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _deadline;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description;
      _assigneeId = t.assigneeId;
      _priority = t.priority;
      _deadline = t.deadline;
    }
    _projectId = widget.initialProjectId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
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
    final ok = await handle(
      context,
      context.read<TaskFormCubit>().save(
            existing: widget.task,
            projectId: _projectId,
            title: _titleCtrl.text,
            description: _descCtrl.text,
            assigneeId: _assigneeId,
            priority: _priority,
            deadline: _deadline,
          ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_editing ? 'Редактирование задачи' : 'Новая задача')),
      body: BlocBuilder<TaskFormCubit, TaskFormState>(
        builder: (context, form) {
          if (form.loading) return const LoadingView();
          if (form.failure != null) {
            return ErrorView(
              failure: form.failure!,
              onRetry: () => context
                  .read<TaskFormCubit>()
                  .init(projectId: widget.initialProjectId),
            );
          }
          return ListView(
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
                value: form.projects.any((p) => p.id == _projectId)
                    ? _projectId
                    : null,
                decoration: const InputDecoration(labelText: 'Проект'),
                items: [
                  for (final p in form.projects)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: _editing
                    ? null
                    : (id) {
                        setState(() {
                          _projectId = id;
                          _assigneeId = null;
                        });
                        context.read<TaskFormCubit>().selectProject(id);
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: form.members.any((u) => u.id == _assigneeId)
                    ? _assigneeId
                    : null,
                decoration: const InputDecoration(
                    labelText: 'Исполнитель (только участники проекта)'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Не назначен')),
                  for (final u in form.members)
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
                  TextButton(
                      onPressed: _pickDeadline, child: const Text('Выбрать')),
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
          );
        },
      ),
    );
  }
}
