import 'package:dartz/dartz.dart';
import 'package:taskflow/constants/app_constants.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/project_repository.dart';
import 'package:taskflow/src/domain/repositories/task_repository.dart';

/// Общие бизнес-правила для задач. Их используют несколько UseCase-ов.

/// Задача должна существовать и не лежать в корзине.
Future<Either<Failure, TaskEntity>> requireActiveTask(
    TaskRepository repo, int taskId) async {
  final result = await repo.getTask(taskId);
  return result.fold<Either<Failure, TaskEntity>>(
    (failure) => Left(failure),
    (task) {
      if (task == null) {
        return const Left(ValidationFailure('Задача не найдена'));
      }
      if (task.isDeleted) {
        return const Left(ValidationFailure('Задача находится в корзине'));
      }
      return Right(task);
    },
  );
}

/// Исполнителем может быть только участник проекта.
Future<Either<Failure, Unit>> requireMember(
    ProjectRepository repo, int projectId, int userId) async {
  final result = await repo.isMember(projectId, userId);
  return result.fold<Either<Failure, Unit>>(
    (failure) => Left(failure),
    (isMember) => isMember
        ? const Right(unit)
        : const Left(
            ValidationFailure('Исполнитель должен быть участником проекта')),
  );
}

/// У исполнителя не больше [kMaxOpenTasksPerDay] незавершённых задач
/// с дедлайном в один и тот же день.
Future<Either<Failure, Unit>> checkDailyLimit(
  TaskRepository repo, {
  required int assigneeId,
  required DateTime? deadline,
  int? exceptTaskId,
}) async {
  if (deadline == null) return const Right(unit);
  final result = await repo.countOpenTasksOnDay(
    assigneeId: assigneeId,
    day: deadline,
    exceptTaskId: exceptTaskId,
  );
  return result.fold<Either<Failure, Unit>>(
    (failure) => Left(failure),
    (count) => count >= kMaxOpenTasksPerDay
        ? Left(ValidationFailure(
            'У исполнителя уже $kMaxOpenTasksPerDay незавершённые задачи '
            'с таким дедлайном'))
        : const Right(unit),
  );
}
