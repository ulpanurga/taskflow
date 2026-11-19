import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/components/helpers.dart';
import 'package:taskflow/components/state_views.dart';
import 'package:taskflow/core/di/injection.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/presentation/bloc/import_cubit.dart';

/// Новая функция СРС 11: загрузить задачи с тестового API
/// и сохранить их в локальную базу проекта.
class ImportPage extends StatelessWidget {
  final int projectId;
  const ImportPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ImportCubit>(param1: projectId),
      child: Scaffold(
        appBar: AppBar(title: const Text('Импорт с сервера')),
        body: BlocConsumer<ImportCubit, ImportState>(
          listener: (context, state) {
            if (state is ImportSaved) {
              showMessage(context, 'Добавлено задач: ${state.count}');
              Navigator.pop(context);
            }
          },
          builder: (context, state) {
            final cubit = context.read<ImportCubit>();

            if (state is ImportLoading) return const LoadingView();

            if (state is ImportError) {
              return ErrorView(failure: state.failure, onRetry: cubit.retry);
            }

            if (state is ImportEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EmptyView(text: 'Сервер вернул пустой список'),
                  FilledButton(
                      onPressed: cubit.fetch, child: const Text('Повторить')),
                ],
              );
            }

            if (state is ImportLoaded) {
              return _TodoList(
                todos: state.todos,
                saving: false,
                onSave: cubit.save,
              );
            }

            if (state is ImportSaving) {
              return _TodoList(
                todos: state.todos,
                saving: true,
                onSave: cubit.save,
              );
            }

            // Initial (и Saved, пока экран закрывается)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_download_outlined, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'Загрузим список задач с тестового сервера. '
                      'Выбранные задачи сохранятся в этот проект на устройстве, '
                      'и потом с ними можно работать без интернета.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: cubit.fetch,
                      icon: const Icon(Icons.download),
                      label: const Text('Загрузить список'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TodoList extends StatelessWidget {
  final List<RemoteTodo> todos;
  final bool saving;
  final VoidCallback onSave;
  const _TodoList(
      {required this.todos, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, i) {
              final t = todos[i];
              return ListTile(
                dense: true,
                leading: Icon(
                  t.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: t.completed ? Colors.green : Colors.grey,
                ),
                title: Text(t.title),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Сохранить ${todos.length} задач в проект'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
