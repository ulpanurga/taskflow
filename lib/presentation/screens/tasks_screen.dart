import 'package:flutter/material.dart';

import '../widgets/task_list_view.dart';
import 'task_form_screen.dart';
import 'trash_screen.dart';

/// Вкладка «Задачи» — все задачи всех проектов.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

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
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
          ),
        ],
      ),
      body: const TaskListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
