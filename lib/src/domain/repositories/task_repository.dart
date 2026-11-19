import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';

abstract class TaskRepository {
  Stream<Either<Failure, List<TaskEntity>>> watchTasks(TaskFilterEntity filter);
  Stream<Either<Failure, TaskEntity?>> watchTask(int id);

  /// Right(null), если такой задачи нет.
  Future<Either<Failure, TaskEntity?>> getTask(int id);

  /// Создаёт задачу и первую запись истории одной транзакцией.
  Future<Either<Failure, int>> createTask({
    required int projectId,
    required String title,
    required String description,
    int? assigneeId,
    required TaskPriority priority,
    DateTime? deadline,
    required int actorId,
  });

  Future<Either<Failure, Unit>> updateTask({
    required int taskId,
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  });

  Future<Either<Failure, Unit>> changePriority(
      int taskId, TaskPriority priority);

  /// Меняет статус и пишет историю одной транзакцией.
  Future<Either<Failure, Unit>> changeStatus({
    required int taskId,
    required TaskStatus oldStatus,
    required TaskStatus newStatus,
    required int actorId,
  });

  /// Меняет исполнителя и пишет историю одной транзакцией.
  Future<Either<Failure, Unit>> reassign({
    required int taskId,
    int? newAssigneeId,
    required int actorId,
  });

  /// Возвращает старый статус, помечает запись истории как отменённую
  /// и добавляет запись «Отмена» — всё одной транзакцией.
  Future<Either<Failure, Unit>> applyUndo({
    required int taskId,
    required int historyId,
    required TaskStatus currentStatus,
    required TaskStatus restoredStatus,
    required int actorId,
  });

  Future<Either<Failure, Unit>> softDelete(int taskId);
  Future<Either<Failure, Unit>> restore({
    required int taskId,
    required TaskStatus status,
    required int actorId,
  });
  Future<Either<Failure, Unit>> deletePermanently(int taskId);

  /// Сколько незавершённых задач у исполнителя с дедлайном в этот день.
  Future<Either<Failure, int>> countOpenTasksOnDay({
    required int assigneeId,
    required DateTime day,
    int? exceptTaskId,
  });

  Stream<Either<Failure, List<HistoryEntryEntity>>> watchHistory(int taskId);

  /// История по возрастанию id.
  Future<Either<Failure, List<HistoryEntryEntity>>> getHistory(int taskId);

  /// Названия всех задач проекта (в том числе из корзины).
  Future<Either<Failure, Set<String>>> existingTitles(int projectId);

  /// Сохраняет задачи, пришедшие с сервера, одной транзакцией.
  Future<Either<Failure, int>> addImportedTasks({
    required int projectId,
    required int actorId,
    required List<RemoteTodo> todos,
  });
}
