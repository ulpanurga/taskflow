import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/data/datasources/local/task_local_datasource.dart';
import 'package:taskflow/src/data/mapper/mappers.dart';
import 'package:taskflow/src/data/repositories/local_repository.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/task_repository.dart';

class TaskRepositoryImpl extends LocalRepository implements TaskRepository {
  final TaskLocalDataSource _local;
  const TaskRepositoryImpl(this._local);

  @override
  Stream<Either<Failure, List<TaskEntity>>> watchTasks(
          TaskFilterEntity filter) =>
      watch(_local
          .watchTasks(filter)
          .map((rows) => rows.map((r) => r.toEntity()).toList()));

  @override
  Stream<Either<Failure, TaskEntity?>> watchTask(int id) =>
      watch<TaskEntity?>(_local.watchTask(id).map((row) => row?.toEntity()));

  @override
  Future<Either<Failure, TaskEntity?>> getTask(int id) => run<TaskEntity?>(
      () async => (await _local.getTask(id))?.toEntity());

  @override
  Future<Either<Failure, int>> createTask({
    required int projectId,
    required String title,
    required String description,
    int? assigneeId,
    required TaskPriority priority,
    DateTime? deadline,
    required int actorId,
  }) =>
      run(() => _local.insertWithHistory(
            projectId: projectId,
            title: title,
            description: description,
            assigneeId: assigneeId,
            priority: priority,
            deadline: deadline,
            actorId: actorId,
          ));

  @override
  Future<Either<Failure, Unit>> updateTask({
    required int taskId,
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) =>
      run(() async {
        await _local.updateFields(
          taskId: taskId,
          title: title,
          description: description,
          priority: priority,
          deadline: deadline,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> changePriority(
          int taskId, TaskPriority priority) =>
      run(() async {
        await _local.updatePriority(taskId, priority);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> changeStatus({
    required int taskId,
    required TaskStatus oldStatus,
    required TaskStatus newStatus,
    required int actorId,
  }) =>
      run(() async {
        await _local.updateStatusWithHistory(
          taskId: taskId,
          oldStatus: oldStatus,
          newStatus: newStatus,
          actorId: actorId,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> reassign({
    required int taskId,
    int? newAssigneeId,
    required int actorId,
  }) =>
      run(() async {
        await _local.reassignWithHistory(
          taskId: taskId,
          newAssigneeId: newAssigneeId,
          actorId: actorId,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> applyUndo({
    required int taskId,
    required int historyId,
    required TaskStatus currentStatus,
    required TaskStatus restoredStatus,
    required int actorId,
  }) =>
      run(() async {
        await _local.undoWithHistory(
          taskId: taskId,
          historyId: historyId,
          currentStatus: currentStatus,
          restoredStatus: restoredStatus,
          actorId: actorId,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> softDelete(int taskId) => run(() async {
        await _local.markDeleted(taskId);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> restore({
    required int taskId,
    required TaskStatus status,
    required int actorId,
  }) =>
      run(() async {
        await _local.restoreWithHistory(
            taskId: taskId, status: status, actorId: actorId);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> deletePermanently(int taskId) =>
      run(() async {
        await _local.deleteForever(taskId);
        return unit;
      });

  @override
  Future<Either<Failure, int>> countOpenTasksOnDay({
    required int assigneeId,
    required DateTime day,
    int? exceptTaskId,
  }) =>
      run(() => _local.countOpenOnDay(assigneeId, day, exceptTaskId));

  @override
  Stream<Either<Failure, List<HistoryEntryEntity>>> watchHistory(
          int taskId) =>
      watch(_local
          .watchHistory(taskId)
          .map((rows) => rows.map((r) => r.toEntity()).toList()));

  @override
  Future<Either<Failure, List<HistoryEntryEntity>>> getHistory(int taskId) =>
      run(() async {
        final rows = await _local.getHistory(taskId);
        return rows.map((h) => h.toEntity()).toList();
      });

  @override
  Future<Either<Failure, Set<String>>> existingTitles(int projectId) =>
      run(() async => (await _local.existingTitles(projectId)).toSet());

  @override
  Future<Either<Failure, int>> addImportedTasks({
    required int projectId,
    required int actorId,
    required List<RemoteTodo> todos,
  }) =>
      run(() => _local.insertImported(
          projectId: projectId, actorId: actorId, todos: todos));
}
