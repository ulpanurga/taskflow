import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/views.dart';
import 'task_repository.dart';

class BenchResult {
  final String name;
  final double withoutIndexMs;
  final double withIndexMs;
  const BenchResult(this.name, this.withoutIndexMs, this.withIndexMs);

  double get speedup => withIndexMs == 0 ? 0 : withoutIndexMs / withIndexMs;
}

/// Сравнение скорости запросов с индексами и без них.
/// Индексы временно удаляются, затем создаются снова.
class IndexBenchmark {
  final AppDatabase _db;
  final TaskRepository _tasks;
  IndexBenchmark(this._db, this._tasks);

  static const int runs = 20;

  Future<List<BenchResult>> run() async {
    final sample = await _tasks.fetchTasks(const TaskFilter(limit: 1));
    if (sample.isEmpty) return [];
    final projectId = sample.first.task.projectId;
    final assigneeId = sample.first.task.assigneeId;

    final cases = <String, TaskFilter>{
      'Фильтр: статус + приоритет':
          const TaskFilter(status: TaskStatus.done, priority: TaskPriority.high),
      'Фильтр: исполнитель': TaskFilter(assigneeId: assigneeId),
      'Фильтр: проект': TaskFilter(projectId: projectId),
      'Сортировка по дедлайну (страница 100)': const TaskFilter(
          sortBy: TaskSort.deadline, ascending: true, offset: 5000),
      'Поиск по названию (LIKE)': const TaskFilter(query: 'отчёт'),
    };

    await _db.dropAllIndexes();
    final without = await _measure(cases);
    await _db.createAllIndexes();
    final withIdx = await _measure(cases);

    return [
      for (final name in cases.keys)
        BenchResult(name, without[name]!, withIdx[name]!),
    ];
  }

  Future<Map<String, double>> _measure(Map<String, TaskFilter> cases) async {
    final result = <String, double>{};
    for (final entry in cases.entries) {
      final f = entry.value.copyWith(limit: 100);
      await _tasks.fetchTasks(f); // прогрев
      final sw = Stopwatch()..start();
      for (var i = 0; i < runs; i++) {
        await _tasks.fetchTasks(f);
      }
      sw.stop();
      result[entry.key] = sw.elapsedMicroseconds / 1000 / runs;
    }
    return result;
  }
}
