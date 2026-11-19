import 'package:drift/drift.dart';
import 'package:taskflow/src/data/datasources/local/app_database.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';

/// Задача + проект + исполнитель (результат JOIN).
class TaskRow {
  final Task task;
  final Project project;
  final User? assignee;
  const TaskRow(this.task, this.project, this.assignee);
}

class HistoryRow {
  final HistoryEntry entry;
  final User? user;
  const HistoryRow(this.entry, this.user);
}

/// Таблицы tasks и task_history.
/// Изменения вместе с записью в историю выполняются одной транзакцией.
class TaskLocalDataSource {
  final AppDatabase _db;
  TaskLocalDataSource(this._db);

  static final List<String> _open = [
    TaskStatus.todo.name,
    TaskStatus.inProgress.name,
  ];

  // ====================== Чтение ======================

  Stream<List<TaskRow>> watchTasks(TaskFilterEntity f) => _select(f).watch();

  Stream<TaskRow?> watchTask(int id) {
    final q = _baseJoin()..where(_db.tasks.id.equals(id));
    return q.map(_toRow).watchSingleOrNull();
  }

  Future<TaskRow?> getTask(int id) {
    final q = _baseJoin()..where(_db.tasks.id.equals(id));
    return q.map(_toRow).getSingleOrNull();
  }

  Stream<List<HistoryRow>> watchHistory(int taskId) {
    final q = _db.select(_db.taskHistory).join([
      leftOuterJoin(
          _db.users, _db.users.id.equalsExp(_db.taskHistory.changedBy)),
    ])
      ..where(_db.taskHistory.taskId.equals(taskId))
      ..orderBy([
        OrderingTerm.desc(_db.taskHistory.changedAt),
        OrderingTerm.desc(_db.taskHistory.id),
      ]);
    return q.watch().map((rows) => rows
        .map((r) =>
            HistoryRow(r.readTable(_db.taskHistory), r.readTableOrNull(_db.users)))
        .toList());
  }

  Future<List<HistoryEntry>> getHistory(int taskId) {
    return (_db.select(_db.taskHistory)
          ..where((h) => h.taskId.equals(taskId))
          ..orderBy([(h) => OrderingTerm.asc(h.id)]))
        .get();
  }

  Future<int> countOpenOnDay(int assigneeId, DateTime day, int? exceptTaskId) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final t = _db.tasks;
    final c = t.id.count();
    Expression<bool> cond = t.assigneeId.equals(assigneeId) &
        t.status.isIn(_open) &
        t.deletedAt.isNull() &
        t.deadline.isBiggerOrEqualValue(dayStart) &
        t.deadline.isSmallerThanValue(dayEnd);
    if (exceptTaskId != null) cond = cond & t.id.equals(exceptTaskId).not();
    final q = _db.selectOnly(t)
      ..addColumns([c])
      ..where(cond);
    return (await q.getSingle()).read(c) ?? 0;
  }

  Future<List<String>> existingTitles(int projectId) async {
    final rows = await (_db.select(_db.tasks)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
    return rows.map((t) => t.title.trim()).toList();
  }

  // ====================== Запись ======================

  Future<int> insertWithHistory({
    required int projectId,
    required String title,
    required String description,
    int? assigneeId,
    required TaskPriority priority,
    DateTime? deadline,
    required int actorId,
  }) {
    return _db.transaction(() async {
      final taskId = await _db.into(_db.tasks).insert(TasksCompanion.insert(
            title: title,
            description: Value(description),
            projectId: projectId,
            assigneeId: Value(assigneeId),
            priority: Value(priority),
            deadline: Value(deadline),
          ));
      await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
            taskId: taskId,
            newStatus: TaskStatus.todo,
            action: const Value(HistoryAction.created),
            changedBy: Value(actorId),
            note: const Value('Задача создана'),
          ));
      return taskId;
    });
  }

  Future<void> updateFields({
    required int taskId,
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        title: Value(title),
        description: Value(description),
        priority: Value(priority),
        deadline: Value(deadline),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updatePriority(int taskId, TaskPriority priority) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        priority: Value(priority),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateStatusWithHistory({
    required int taskId,
    required TaskStatus oldStatus,
    required TaskStatus newStatus,
    required int actorId,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
            taskId: taskId,
            oldStatus: Value(oldStatus),
            newStatus: newStatus,
            action: const Value(HistoryAction.statusChanged),
            changedBy: Value(actorId),
          ));
    });
  }

  Future<void> reassignWithHistory({
    required int taskId,
    int? newAssigneeId,
    required int actorId,
  }) {
    return _db.transaction(() async {
      final task = await (_db.select(_db.tasks)
            ..where((t) => t.id.equals(taskId)))
          .getSingle();
      final oldName = await _userName(task.assigneeId);
      final newName = await _userName(newAssigneeId);

      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          assigneeId: Value(newAssigneeId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
            taskId: taskId,
            oldStatus: Value(task.status),
            newStatus: task.status,
            action: const Value(HistoryAction.reassigned),
            changedBy: Value(actorId),
            note: Value('Исполнитель: $oldName → $newName'),
          ));
    });
  }

  Future<void> undoWithHistory({
    required int taskId,
    required int historyId,
    required TaskStatus currentStatus,
    required TaskStatus restoredStatus,
    required int actorId,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(restoredStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (_db.update(_db.taskHistory)..where((h) => h.id.equals(historyId)))
          .write(const TaskHistoryCompanion(isUndone: Value(true)));
      await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
            taskId: taskId,
            oldStatus: Value(currentStatus),
            newStatus: restoredStatus,
            action: const Value(HistoryAction.undo),
            changedBy: Value(actorId),
            note: const Value('Отмена последнего изменения статуса'),
          ));
    });
  }

  Future<void> markDeleted(int taskId) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restoreWithHistory({
    required int taskId,
    required TaskStatus status,
    required int actorId,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
            taskId: taskId,
            oldStatus: Value(status),
            newStatus: status,
            action: const Value(HistoryAction.restored),
            changedBy: Value(actorId),
            note: const Value('Задача восстановлена из корзины'),
          ));
    });
  }

  Future<void> deleteForever(int taskId) async {
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(taskId))).go();
  }

  /// Импорт: все задачи и их история сохраняются вместе или не сохраняются.
  Future<int> insertImported({
    required int projectId,
    required int actorId,
    required List<RemoteTodo> todos,
  }) {
    return _db.transaction(() async {
      for (final todo in todos) {
        final status = todo.completed ? TaskStatus.done : TaskStatus.todo;
        final taskId = await _db.into(_db.tasks).insert(TasksCompanion.insert(
              title: todo.title.trim(),
              description: const Value('Импортировано с сервера'),
              projectId: projectId,
              status: Value(status),
            ));
        await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
              taskId: taskId,
              newStatus: status,
              action: const Value(HistoryAction.created),
              changedBy: Value(actorId),
              note: const Value('Импорт с сервера'),
            ));
      }
      return todos.length;
    });
  }

  // ====================== Внутреннее ======================

  JoinedSelectStatement<HasResultSet, dynamic> _baseJoin() {
    return _db.select(_db.tasks).join([
      innerJoin(_db.projects, _db.projects.id.equalsExp(_db.tasks.projectId)),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.tasks.assigneeId)),
    ]);
  }

  TaskRow _toRow(TypedResult r) => TaskRow(
        r.readTable(_db.tasks),
        r.readTable(_db.projects),
        r.readTableOrNull(_db.users),
      );

  Selectable<TaskRow> _select(TaskFilterEntity f) {
    final q = _baseJoin()..where(_predicate(f));
    final sortColumn =
        f.sortBy == TaskSort.deadline ? _db.tasks.deadline : _db.tasks.createdAt;
    final mode = f.ascending ? OrderingMode.asc : OrderingMode.desc;
    q.orderBy([
      OrderingTerm(expression: sortColumn, mode: mode),
      OrderingTerm(expression: _db.tasks.id, mode: mode),
    ]);
    q.limit(f.limit, offset: f.offset);
    return q.map(_toRow);
  }

  Expression<bool> _predicate(TaskFilterEntity f) {
    final t = _db.tasks;
    Expression<bool> e =
        f.onlyDeleted ? t.deletedAt.isNotNull() : t.deletedAt.isNull();
    if (f.projectId != null) e = e & t.projectId.equals(f.projectId!);
    if (f.status != null) e = e & t.status.equalsValue(f.status!);
    if (f.priority != null) e = e & t.priority.equalsValue(f.priority!);
    if (f.assigneeId != null) e = e & t.assigneeId.equals(f.assigneeId!);
    final s = f.query.trim();
    if (s.isNotEmpty) {
      final like = '%$s%';
      e = e & (t.title.like(like) | t.description.like(like));
    }
    return e;
  }

  Future<String> _userName(int? id) async {
    if (id == null) return 'не назначен';
    final u = await (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
    return u?.name ?? 'не назначен';
  }
}
