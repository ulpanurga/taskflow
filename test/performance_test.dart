import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/models/views.dart';
import 'package:taskflow/repositories/data_seeder.dart';
import 'package:taskflow/repositories/index_benchmark.dart';
import 'package:taskflow/repositories/task_repository.dart';

/// Тест производительности: 1000 пользователей, 100 проектов, 10 000 задач.
/// Запуск:  flutter test test/performance_test.dart
void main() {
  test('Данные создаются, пагинация работает, индексы сравниваются', () async {
    final db = AppDatabase.memory();
    final tasks = TaskRepository(db);

    await DataSeeder(db).seed();

    expect((await db.select(db.users).get()).length, 1000);
    expect((await db.select(db.projects).get()).length, 100);
    expect(await tasks.count(const TaskFilter()), 10000);

    // Пагинация
    final p1 = await tasks.fetchTasks(const TaskFilter(limit: 50, offset: 0));
    final p2 = await tasks.fetchTasks(const TaskFilter(limit: 50, offset: 50));
    expect(p1.length, 50);
    expect(p2.length, 50);
    expect(p1.first.task.id, isNot(p2.first.task.id));

    // Сравнение скорости
    final results = await IndexBenchmark(db, tasks).run();
    // ignore: avoid_print
    print('\n=== Сравнение скорости (мс на запрос, среднее из ${IndexBenchmark.runs}) ===');
    for (final r in results) {
      // ignore: avoid_print
      print('${r.name}\n'
          '   без индексов: ${r.withoutIndexMs.toStringAsFixed(2)} мс\n'
          '   с индексами:  ${r.withIndexMs.toStringAsFixed(2)} мс '
          '(быстрее в ${r.speedup.toStringAsFixed(1)} раз)');
    }
    expect(results, isNotEmpty);

    await db.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
