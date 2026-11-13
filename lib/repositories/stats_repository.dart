import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/views.dart';

/// Вся статистика считается SQL-запросами к SQLite.
class StatsRepository {
  final AppDatabase _db;
  StatsRepository(this._db);

  Future<DashboardStats> load() async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. Общие числа одним запросом
    final totals = await _db.customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM projects) AS projects,
        (SELECT COUNT(*) FROM tasks WHERE deleted_at IS NULL) AS total,
        (SELECT COUNT(*) FROM tasks
           WHERE deleted_at IS NULL AND status = 'done') AS done,
        (SELECT COUNT(*) FROM tasks
           WHERE deleted_at IS NULL AND status IN ('todo', 'inProgress')) AS not_done,
        (SELECT COUNT(*) FROM tasks
           WHERE deleted_at IS NULL
             AND status IN ('todo', 'inProgress')
             AND deadline IS NOT NULL
             AND deadline < ?) AS overdue
      ''',
      variables: [Variable<int>(nowSeconds)],
    ).getSingle();

    // 2. Задачи по приоритетам
    final priorityRows = await _db.customSelect(
      '''
      SELECT priority, COUNT(*) AS cnt
      FROM tasks
      WHERE deleted_at IS NULL
      GROUP BY priority
      ''',
    ).get();
    final byPriority = {for (final p in TaskPriority.values) p: 0};
    for (final r in priorityRows) {
      final name = r.read<String>('priority');
      final p = TaskPriority.values.where((e) => e.name == name);
      if (p.isNotEmpty) byPriority[p.first] = r.read<int>('cnt');
    }

    // 3. Задачи у каждого исполнителя
    final assigneeRows = await _db.customSelect(
      '''
      SELECT u.name AS name, COUNT(t.id) AS cnt
      FROM users u
      INNER JOIN tasks t ON t.assignee_id = u.id AND t.deleted_at IS NULL
      GROUP BY u.id
      ORDER BY cnt DESC, u.name ASC
      ''',
    ).get();
    final byAssignee = assigneeRows
        .map((r) => AssigneeCount(r.read<String>('name'), r.read<int>('cnt')))
        .toList();

    // 4. Процент выполнения каждого проекта
    final projectRows = await _db.customSelect(
      '''
      SELECT p.id AS id, p.name AS name,
             COUNT(t.id) AS total,
             COALESCE(SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END), 0) AS done,
             COALESCE(ROUND(100.0 * SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END)
                            / NULLIF(COUNT(t.id), 0), 1), 0) AS percent
      FROM projects p
      LEFT JOIN tasks t ON t.project_id = p.id AND t.deleted_at IS NULL
      GROUP BY p.id
      ORDER BY p.name ASC
      ''',
    ).get();
    final progress = projectRows
        .map((r) => ProjectProgress(
              r.read<int>('id'),
              r.read<String>('name'),
              r.read<int>('total'),
              r.read<int>('done'),
              (r.data['percent'] as num).toDouble(),
            ))
        .toList();

    return DashboardStats(
      projects: totals.read<int>('projects'),
      tasks: totals.read<int>('total'),
      done: totals.read<int>('done'),
      notDone: totals.read<int>('not_done'),
      overdue: totals.read<int>('overdue'),
      byPriority: byPriority,
      byAssignee: byAssignee,
      projectProgress: progress,
    );
  }

  /// Статистика пересчитывается при любом изменении этих таблиц.
  Stream<DashboardStats> watch() async* {
    yield await load();
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables(
        [_db.tasks, _db.projects, _db.users]))) {
      yield await load();
    }
  }
}
