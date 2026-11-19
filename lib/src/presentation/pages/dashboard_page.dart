import 'package:flutter/material.dart';
import 'package:taskflow/components/helpers.dart';
import 'package:taskflow/components/state_views.dart';
import 'package:taskflow/src/domain/entities/dashboard_stats_entity.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/presentation/bloc/dashboard_cubit.dart';

/// Панель статистики. Все числа считаются SQL-запросами в Data Layer.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: DataStateView<DashboardCubit, DashboardStatsEntity>(
        emptyText: 'Данных пока нет',
        builder: (context, s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric('Проектов', s.projects, Colors.indigo),
                _Metric('Всего задач', s.tasks, Colors.blueGrey),
                _Metric('Завершено', s.done, Colors.green),
                _Metric('Не завершено', s.notDone, Colors.blue),
                _Metric('Просрочено', s.overdue, Colors.red),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Задачи по приоритетам',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (final p in TaskPriority.values)
              ListTile(
                dense: true,
                leading: Icon(Icons.flag, color: priorityColor(p)),
                title: Text(p.title),
                trailing: Text('${s.byPriority[p] ?? 0}'),
              ),
            const SizedBox(height: 16),
            const Text('Выполнение проектов',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (final p in s.projectProgress)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.name} — ${p.percent.toStringAsFixed(1)}% '
                        '(${p.done} из ${p.total})'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: p.percent / 100),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('Задачи у исполнителей',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (s.byAssignee.isEmpty) const Text('Нет назначенных задач'),
            for (final a in s.byAssignee)
              ListTile(
                dense: true,
                title: Text(a.name),
                trailing: Text('${a.count}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Metric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(label),
        ],
      ),
    );
  }
}
