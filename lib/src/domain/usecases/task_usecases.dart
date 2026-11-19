import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/project_repository.dart';
import 'package:taskflow/src/domain/repositories/task_repository.dart';
import 'package:taskflow/src/domain/usecases/task_rules.dart';

const _emptyTitle = ValidationFailure('Название задачи не может быть пустым');

class WatchTasks {
  final TaskRepository _repo;
  const WatchTasks(this._repo);

  Stream<Either<Failure, List<TaskEntity>>> call(TaskFilterEntity filter) =>
      _repo.watchTasks(filter);
}

class WatchTask {
  final TaskRepository _repo;
  const WatchTask(this._repo);

  Stream<Either<Failure, TaskEntity?>> call(int id) => _repo.watchTask(id);
}

class WatchTaskHistory {
  final TaskRepository _repo;
  const WatchTaskHistory(this._repo);

  Stream<Either<Failure, List<HistoryEntryEntity>>> call(int taskId) =>
      _repo.watchHistory(taskId);
}

class CreateTask {
  final TaskRepository _tasks;
  final ProjectRepository _projects;
  const CreateTask(this._tasks, this._projects);

  Future<Either<Failure, int>> call({
    int? projectId,
    required String title,
    String description = '',
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    DateTime? deadline,
    required int actorId,
  }) async {
    if (projectId == null) {
      return const Left(ValidationFailure('Задача должна принадлежать проекту'));
    }
    if (title.trim().isEmpty) return const Left(_emptyTitle);

    if (assigneeId != null) {
      final member = await requireMember(_projects, projectId, assigneeId);
      final limit = await member.thenAsync<Unit>((_) => checkDailyLimit(
            _tasks,
            assigneeId: assigneeId,
            deadline: deadline,
          ));
      final failure = limit.failureOrNull;
      if (failure != null) return Left(failure);
    }

    return _tasks.createTask(
      projectId: projectId,
      title: title.trim(),
      description: description,
      assigneeId: assigneeId,
      priority: priority,
      deadline: deadline,
      actorId: actorId,
    );
  }
}

class UpdateTask {
  final TaskRepository _repo;
  const UpdateTask(this._repo);

  Future<Either<Failure, Unit>> call({
    required int taskId,
    required String title,
    String description = '',
    required TaskPriority priority,
    DateTime? deadline,
  }) async {
    final active = await requireActiveTask(_repo, taskId);
    return active.thenAsync<Unit>((task) async {
      if (title.trim().isEmpty) return const Left(_emptyTitle);

      final deadlineChanged = task.deadline != deadline;
      if (deadlineChanged && task.assigneeId != null && task.status.isOpen) {
        final limit = await checkDailyLimit(
          _repo,
          assigneeId: task.assigneeId!,
          deadline: deadline,
          exceptTaskId: taskId,
        );
        final failure = limit.failureOrNull;
        if (failure != null) return Left(failure);
      }

      return _repo.updateTask(
        taskId: taskId,
        title: title.trim(),
        description: description,
        priority: priority,
        deadline: deadline,
      );
    });
  }
}

class ChangeTaskPriority {
  final TaskRepository _repo;
  const ChangeTaskPriority(this._repo);

  Future<Either<Failure, Unit>> call(
      {required int taskId, required TaskPriority priority}) async {
    final active = await requireActiveTask(_repo, taskId);
    return active.thenAsync<Unit>(
        (_) => _repo.changePriority(taskId, priority));
  }
}

class ChangeTaskStatus {
  final TaskRepository _repo;
  const ChangeTaskStatus(this._repo);

  Future<Either<Failure, Unit>> call({
    required int taskId,
    required TaskStatus newStatus,
    required int actorId,
  }) async {
    final active = await requireActiveTask(_repo, taskId);
    return active.thenAsync<Unit>((task) async {
      if (task.status == newStatus) return const Right(unit);
      return _repo.changeStatus(
        taskId: taskId,
        oldStatus: task.status,
        newStatus: newStatus,
        actorId: actorId,
      );
    });
  }
}

class ReassignTask {
  final TaskRepository _tasks;
  final ProjectRepository _projects;
  const ReassignTask(this._tasks, this._projects);

  Future<Either<Failure, Unit>> call({
    required int taskId,
    int? newAssigneeId,
    required int actorId,
  }) async {
    final active = await requireActiveTask(_tasks, taskId);
    return active.thenAsync<Unit>((task) async {
      if (task.assigneeId == newAssigneeId) return const Right(unit);

      if (newAssigneeId != null) {
        final member =
            await requireMember(_projects, task.projectId, newAssigneeId);
        final memberFailure = member.failureOrNull;
        if (memberFailure != null) return Left(memberFailure);

        if (task.status.isOpen) {
          final limit = await checkDailyLimit(
            _tasks,
            assigneeId: newAssigneeId,
            deadline: task.deadline,
            exceptTaskId: taskId,
          );
          final limitFailure = limit.failureOrNull;
          if (limitFailure != null) return Left(limitFailure);
        }
      }

      return _tasks.reassign(
        taskId: taskId,
        newAssigneeId: newAssigneeId,
        actorId: actorId,
      );
    });
  }
}

/// Отменяет последнее ещё не отменённое изменение статуса.
class UndoStatusChange {
  final TaskRepository _repo;
  const UndoStatusChange(this._repo);

  Future<Either<Failure, TaskStatus>> call(
      {required int taskId, required int actorId}) async {
    final active = await requireActiveTask(_repo, taskId);
    return active.thenAsync<TaskStatus>((task) async {
      final historyResult = await _repo.getHistory(taskId);
      return historyResult.thenAsync<TaskStatus>((history) async {
        HistoryEntryEntity? last;
        for (final entry in history.reversed) {
          if (entry.action == HistoryAction.statusChanged &&
              !entry.isUndone &&
              entry.oldStatus != null) {
            last = entry;
            break;
          }
        }
        if (last == null) {
          return const Left(
              ValidationFailure('Нет изменений статуса для отмены'));
        }

        final restored = last.oldStatus!;
        final result = await _repo.applyUndo(
          taskId: taskId,
          historyId: last.id,
          currentStatus: task.status,
          restoredStatus: restored,
          actorId: actorId,
        );
        return result.map((_) => restored);
      });
    });
  }
}

/// Мягкое удаление: задача уходит в корзину.
class MoveTaskToTrash {
  final TaskRepository _repo;
  const MoveTaskToTrash(this._repo);

  Future<Either<Failure, Unit>> call(int taskId) async {
    final active = await requireActiveTask(_repo, taskId);
    return active.thenAsync<Unit>((_) => _repo.softDelete(taskId));
  }
}

class RestoreTask {
  final TaskRepository _repo;
  const RestoreTask(this._repo);

  Future<Either<Failure, Unit>> call(
      {required int taskId, required int actorId}) async {
    final result = await _repo.getTask(taskId);
    return result.thenAsync<Unit>((task) async {
      if (task == null || !task.isDeleted) {
        return const Left(ValidationFailure('Задача не находится в корзине'));
      }
      return _repo.restore(
          taskId: taskId, status: task.status, actorId: actorId);
    });
  }
}

/// Полностью удалить можно только задачу из корзины.
class DeleteTaskPermanently {
  final TaskRepository _repo;
  const DeleteTaskPermanently(this._repo);

  Future<Either<Failure, Unit>> call(int taskId) async {
    final result = await _repo.getTask(taskId);
    return result.thenAsync<Unit>((task) async {
      if (task == null) return const Right(unit);
      if (!task.isDeleted) {
        return const Left(
            ValidationFailure('Сначала переместите задачу в корзину'));
      }
      return _repo.deletePermanently(taskId);
    });
  }
}
