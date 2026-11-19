import 'package:flutter/material.dart';
import 'package:taskflow/src/presentation/pages/task_form_page.dart';
import 'package:taskflow/src/presentation/pages/trash_page.dart';
import 'package:taskflow/src/presentation/widgets/task_list_view.dart';

/// Вкладка «Задачи» — все задачи всех проектов.
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи'),
        actions: [
          IconButton(
            tooltip: 'Корзина',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashPage()),
            ),
          ),
        ],
      ),
      body: const TaskListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskFormPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
