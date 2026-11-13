import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/views.dart';
import '../../repositories/data_seeder.dart';
import '../../repositories/index_benchmark.dart';
import '../../repositories/stats_repository.dart';
import '../helpers.dart';

/// Панель статистики. Все числа считаются SQL-запросами.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Stream<DashboardStats> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<StatsRepository>().watch();
  }

  Future<void> _seed() async {
    if (!await confirm(context,
        'Создать 1000 пользователей, 100 проектов и 10 000 задач? Это займёт несколько секунд.')) {
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Заполняю базу...'),
        ]),
      ),
    );
    final seeder = context.read<DataSeeder>();
    final nav = Navigator.of(context);
    try {
      await seeder.seed();
    } finally {
      nav.pop();
    }
  }

  Future<void> _benchmark() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Измеряю скорость...'),
        ]),
      ),
    );
    final bench = context.read<IndexBenchmark>();
    final nav = Navigator.of(context);
    List<BenchResult> results;
    try {
      results = await bench.run();
    } finally {
      nav.pop();
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Индексы: сравнение'),
        content: SingleChildScrollView(
          child: results.isEmpty
              ? const Text('Сначала создайте тестовые данные')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in results)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${r.name}\n'
                          'без индексов: ${r.withoutIndexMs.toStringAsFixed(2)} мс\n'
                          'с индексами: ${r.withIndexMs.toStringAsFixed(2)} мс '
                          '(в ${r.speedup.toStringAsFixed(1)} раз)',
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'seed') _seed();
              if (v == 'bench') _benchmark();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'seed', child: Text('Создать тестовые данные')),
              PopupMenuItem(value: 'bench', child: Text('Сравнить скорость с индексами')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DashboardStats>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Ошибка: ${snap.error}'));
          final s = snap.data;
          if (s == null) return const Center(child: CircularProgressIndicator());
          return ListView(
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
          );
        },
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
