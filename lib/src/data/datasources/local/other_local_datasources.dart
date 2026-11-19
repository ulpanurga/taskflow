import 'dart:async';

import 'package:drift/drift.dart';
import 'package:taskflow/models/dashboard_stats_model.dart';
import 'package:taskflow/src/data/datasources/local/app_database.dart';

/// Комментарий + автор (результат JOIN).
class CommentRow {
  final Comment comment;
  final User author;
  const CommentRow(this.comment, this.author);
}

class CommentLocalDataSource {
  final AppDatabase _db;
  CommentLocalDataSource(this._db);

  Stream<List<CommentRow>> watchForTask(int taskId) {
    final q = _db.select(_db.comments).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.comments.authorId)),
    ])
      ..where(_db.comments.taskId.equals(taskId))
      ..orderBy([
        OrderingTerm.asc(_db.comments.createdAt),
        OrderingTerm.asc(_db.comments.id),
      ]);
    return q.watch().map((rows) => rows
        .map((r) => CommentRow(r.readTable(_db.comments), r.readTable(_db.users)))
        .toList());
  }

  Future<CommentRow?> getById(int id) async {
    final q = _db.select(_db.comments).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.comments.authorId)),
    ])
      ..where(_db.comments.id.equals(id));
    final r = await q.getSingleOrNull();
    if (r == null) return null;
    return CommentRow(r.readTable(_db.comments), r.readTable(_db.users));
  }

  Future<int> insert(int taskId, int authorId, String body) {
    return _db.into(_db.comments).insert(CommentsCompanion.insert(
          body: body,
          authorId: authorId,
          taskId: taskId,
        ));
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.comments)..where((c) => c.id.equals(id))).go();
  }
}

/// В базе хранится только путь к файлу, а не сам файл.
class AttachmentLocalDataSource {
  final AppDatabase _db;
  AttachmentLocalDataSource(this._db);

  Stream<List<Attachment>> watchForTask(int taskId) {
    return (_db.select(_db.attachments)
          ..where((a) => a.taskId.equals(taskId))
          ..orderBy([
            (a) => OrderingTerm.desc(a.addedAt),
            (a) => OrderingTerm.desc(a.id),
          ]))
        .watch();
  }

  Future<int> insert(int taskId, String fileName, String filePath) {
    return _db.into(_db.attachments).insert(AttachmentsCompanion.insert(
          fileName: fileName,
          filePath: filePath,
          taskId: taskId,
        ));
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
  }
}

/// Вся статистика считается SQL-запросами.
class StatsLocalDataSource {
  final AppDatabase _db;
  StatsLocalDataSource(this._db);

  Future<DashboardStatsModel> load() async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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

    final priorityRows = await _db.customSelect(
      '''
      SELECT priority, COUNT(*) AS cnt
      FROM tasks
      WHERE deleted_at IS NULL
      GROUP BY priority
      ''',
    ).get();
    final byPriority = <String, int>{
      for (final r in priorityRows) r.read<String>('priority'): r.read<int>('cnt'),
    };

    final assigneeRows = await _db.customSelect(
      '''
      SELECT u.name AS name, COUNT(t.id) AS cnt
      FROM users u
      INNER JOIN tasks t ON t.assignee_id = u.id AND t.deleted_at IS NULL
      GROUP BY u.id
      ORDER BY cnt DESC, u.name ASC
      ''',
    ).get();

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

    return DashboardStatsModel(
      projects: totals.read<int>('projects'),
      tasks: totals.read<int>('total'),
      done: totals.read<int>('done'),
      notDone: totals.read<int>('not_done'),
      overdue: totals.read<int>('overdue'),
      byPriority: byPriority,
      byAssignee: assigneeRows
          .map((r) =>
              AssigneeCountModel(r.read<String>('name'), r.read<int>('cnt')))
          .toList(),
      projectProgress: projectRows
          .map((r) => ProjectProgressModel(
                r.read<int>('id'),
                r.read<String>('name'),
                r.read<int>('total'),
                r.read<int>('done'),
                (r.data['percent'] as num).toDouble(),
              ))
          .toList(),
    );
  }

  /// Статистика пересчитывается при любом изменении этих таблиц.
  Stream<DashboardStatsModel> watch() async* {
    yield await load();
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables(
        [_db.tasks, _db.projects, _db.users]))) {
      yield await load();
    }
  }
}
