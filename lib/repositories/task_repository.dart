import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/exceptions.dart';
import '../models/views.dart';

/// Максимум незавершённых задач у одного исполнителя на один день дедлайна.
const int kMaxOpenTasksPerDay = 3;

class TaskRepository {
  final AppDatabase _db;
  TaskRepository(this._db);

  static final List<String> _openStatuses = [
    TaskStatus.todo.name,
    TaskStatus.inProgress.name,
  ];

  // ====================== Создание / изменение ======================

  /// Создание задачи и первая запись в истории — одна транзакция.
  /// Если запись истории не сохранилась, задача тоже не сохраняется.
  Future<int> createTask({
    required int? projectId,
    required String title,
    String description = '',
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    DateTime? deadline,
    required int actorId,
  }) {
    return _db.transaction(() async {
      if (projectId == null) {
        throw const ValidationException('Задача должна принадлежать проекту');
      }
      if (title.trim().isEmpty) {
        throw const ValidationException('Название задачи не может быть пустым');
      }
      await _requireProject(projectId);
      if (assigneeId != null) {
        await _requireMember(projectId, assigneeId);
        await _checkDailyLimit(assigneeId, deadline);
      }

      final taskId = await _db.into(_db.tasks).insert(TasksCompanion.insert(
            title: title.trim(),
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

  /// Редактирование названия, описания, приоритета и дедлайна.
  Future<void> updateTask(
    int taskId, {
    required String title,
    String description = '',
    required TaskPriority priority,
    DateTime? deadline,
  }) {
    return _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      if (title.trim().isEmpty) {
        throw const ValidationException('Название задачи не может быть пустым');
      }
      final deadlineChanged = task.deadline != deadline;
      if (deadlineChanged && task.assigneeId != null && task.status.isOpen) {
        await _checkDailyLimit(task.assigneeId!, deadline, exceptTaskId: taskId);
      }
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          title: Value(title.trim()),
          description: Value(description),
          priority: Value(priority),
          deadline: Value(deadline),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> changePriority(int taskId, TaskPriority priority) async {
    await _requireActiveTask(taskId);
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        priority: Value(priority),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Смена статуса + автоматическая запись в историю (атомарно).
  Future<void> changeStatus(int taskId, TaskStatus newStatus, int actorId) {
    return _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      if (task.status == newStatus) return;
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
            taskId: taskId,
            oldStatus: Value(task.status),
            newStatus: newStatus,
            action: const Value(HistoryAction.statusChanged),
            changedBy: Value(actorId),
          ));
    });
  }

  /// Назначение / переназначение исполнителя:
  /// проверка участия в проекте, проверка лимита, смена и запись в историю.
  Future<void> reassign(int taskId, int? newAssigneeId, int actorId) {
    return _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      if (newAssigneeId != null) {
        await _requireMember(task.projectId, newAssigneeId);
        if (task.status.isOpen) {
          await _checkDailyLimit(newAssigneeId, task.deadline,
              exceptTaskId: taskId);
        }
      }
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

  /// Undo: отменяет последнее ещё не отменённое изменение статуса.
  Future<TaskStatus> undoLastStatusChange(int taskId, int actorId) {
    return _db.transaction(() async {
      final task = await _requireActiveTask(taskId);
      final last = await (_db.select(_db.taskHistory)
            ..where((h) =>
                h.taskId.equals(taskId) &
                h.action.equalsValue(HistoryAction.statusChanged) &
                h.isUndone.equals(false))
            ..orderBy([
              (h) => OrderingTerm.desc(h.id),
            ])
            ..limit(1))
          .getSingleOrNull();
      if (last == null || last.oldStatus == null) {
        throw const ValidationException('Нет изменений статуса для отмены');
      }
      final restored = last.oldStatus!;
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(restored),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (_db.update(_db.taskHistory)..where((h) => h.id.equals(last.id)))
          .write(const TaskHistoryCompanion(isUndone: Value(true)));
      await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
            taskId: taskId,
            oldStatus: Value(task.status),
            newStatus: restored,
            action: const Value(HistoryAction.undo),
            changedBy: Value(actorId),
            note: const Value('Отмена последнего изменения статуса'),
          ));
      return restored;
    });
  }

  // ====================== Корзина (Soft Delete) ======================

  Future<void> softDelete(int taskId) async {
    await _requireActiveTask(taskId);
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restore(int taskId, int actorId) {
    return _db.transaction(() async {
      final task = await getById(taskId);
      if (task == null || task.deletedAt == null) {
        throw const ValidationException('Задача не находится в корзине');
      }
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.into(_db.taskHistory).insert(TaskHistoryCompanion.insert(
            taskId: taskId,
            oldStatus: Value(task.status),
            newStatus: task.status,
            action: const Value(HistoryAction.restored),
            changedBy: Value(actorId),
            note: const Value('Задача восстановлена из корзины'),
          ));
    });
  }

  /// Полное удаление возможно только для задач из корзины.
  Future<void> deletePermanently(int taskId) async {
    final task = await getById(taskId);
    if (task == null) return;
    if (task.deletedAt == null) {
      throw const ValidationException(
          'Сначала переместите задачу в корзину');
    }
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(taskId))).go();
  }

  // ====================== Чтение ======================

  Future<Task?> getById(int id) {
    return (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<TaskView?> watchTask(int id) {
    final q = _baseJoin()..where(_db.tasks.id.equals(id));
    return q.map(_toView).watchSingleOrNull();
  }

  Stream<List<TaskView>> watchTasks(TaskFilter f) => _select(f).watch();

  Future<List<TaskView>> fetchTasks(TaskFilter f) => _select(f).get();

  Future<int> count(TaskFilter f) async {
    final c = _db.tasks.id.count();
    final q = _db.selectOnly(_db.tasks)
      ..addColumns([c])
      ..where(_predicate(f));
    return (await q.getSingle()).read(c) ?? 0;
  }

  Stream<List<HistoryView>> watchHistory(int taskId) {
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
        .map((r) => HistoryView(
              r.readTable(_db.taskHistory),
              r.readTableOrNull(_db.users),
            ))
        .toList());
  }

  Future<List<HistoryEntry>> getHistory(int taskId) {
    return (_db.select(_db.taskHistory)
          ..where((h) => h.taskId.equals(taskId))
          ..orderBy([(h) => OrderingTerm.asc(h.id)]))
        .get();
  }

  // ====================== Внутренние методы ======================

  JoinedSelectStatement<HasResultSet, dynamic> _baseJoin() {
    return _db.select(_db.tasks).join([
      innerJoin(_db.projects, _db.projects.id.equalsExp(_db.tasks.projectId)),
      leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.tasks.assigneeId)),
    ]);
  }

  TaskView _toView(TypedResult r) => TaskView(
        r.readTable(_db.tasks),
        r.readTable(_db.projects),
        r.readTableOrNull(_db.users),
      );

  Selectable<TaskView> _select(TaskFilter f) {
    final q = _baseJoin()..where(_predicate(f));
    final sortColumn =
        f.sortBy == TaskSort.deadline ? _db.tasks.deadline : _db.tasks.createdAt;
    final mode = f.ascending ? OrderingMode.asc : OrderingMode.desc;
    q.orderBy([
      OrderingTerm(expression: sortColumn, mode: mode),
      OrderingTerm(expression: _db.tasks.id, mode: mode),
    ]);
    q.limit(f.limit, offset: f.offset);
    return q.map(_toView);
  }

  Expression<bool> _predicate(TaskFilter f) {
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

  Future<void> _requireProject(int projectId) async {
    final p = await (_db.select(_db.projects)
          ..where((p) => p.id.equals(projectId)))
        .getSingleOrNull();
    if (p == null) throw const ValidationException('Проект не найден');
  }

  Future<Task> _requireActiveTask(int taskId) async {
    final task = await getById(taskId);
    if (task == null) throw const ValidationException('Задача не найдена');
    if (task.deletedAt != null) {
      throw const ValidationException('Задача находится в корзине');
    }
    return task;
  }

  /// Исполнителем может быть только участник проекта.
  Future<void> _requireMember(int projectId, int userId) async {
    final rows = await (_db.select(_db.projectMembers)
          ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .get();
    if (rows.isEmpty) {
      throw const ValidationException(
          'Исполнитель должен быть участником проекта');
    }
  }

  /// Не более 3 незавершённых задач на один день дедлайна у исполнителя.
  /// Проверка делается запросом к базе данных.
  Future<void> _checkDailyLimit(int assigneeId, DateTime? deadline,
      {int? exceptTaskId}) async {
    if (deadline == null) return;
    final dayStart = DateTime(deadline.year, deadline.month, deadline.day);
    final dayEnd = DateTime(deadline.year, deadline.month, deadline.day + 1);
    final t = _db.tasks;
    final c = t.id.count();
    Expression<bool> cond = t.assigneeId.equals(assigneeId) &
        t.status.isIn(_openStatuses) &
        t.deletedAt.isNull() &
        t.deadline.isBiggerOrEqualValue(dayStart) &
        t.deadline.isSmallerThanValue(dayEnd);
    if (exceptTaskId != null) cond = cond & t.id.equals(exceptTaskId).not();
    final q = _db.selectOnly(t)
      ..addColumns([c])
      ..where(cond);
    final n = (await q.getSingle()).read(c) ?? 0;
    if (n >= kMaxOpenTasksPerDay) {
      throw const ValidationException(
          'У исполнителя уже 3 незавершённые задачи с таким дедлайном');
    }
  }

  Future<String> _userName(int? id) async {
    if (id == null) return 'не назначен';
    final u = await (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
    return u?.name ?? 'не назначен';
  }
}
