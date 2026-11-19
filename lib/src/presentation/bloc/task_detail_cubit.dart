import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

/// Экран одной задачи. Состояние Empty значит «задача не найдена».
class TaskDetailCubit extends WatchCubit<TaskEntity?> {
  final int taskId;
  final WatchTask _watch;
  final ChangeTaskStatus _changeStatus;
  final ChangeTaskPriority _changePriority;
  final ReassignTask _reassign;
  final UndoStatusChange _undo;
  final MoveTaskToTrash _trash;
  final GetMemberUsers _getMembers;
  final SessionCubit _session;

  TaskDetailCubit(
    this.taskId,
    this._watch,
    this._changeStatus,
    this._changePriority,
    this._reassign,
    this._undo,
    this._trash,
    this._getMembers,
    this._session,
  );

  @override
  Stream<Either<Failure, TaskEntity?>> watchSource() => _watch(taskId);

  @override
  bool isEmptyData(TaskEntity? data) => data == null;

  Future<Failure?> changeStatus(TaskStatus status) async {
    final actor = _session.state;
    if (actor == null) return SessionCubit.noUserFailure;
    return (await _changeStatus(
            taskId: taskId, newStatus: status, actorId: actor))
        .failureOrNull;
  }

  Future<Failure?> changePriority(TaskPriority priority) async =>
      (await _changePriority(taskId: taskId, priority: priority)).failureOrNull;

  Future<Failure?> reassign(int? assigneeId) async {
    final actor = _session.state;
    if (actor == null) return SessionCubit.noUserFailure;
    return (await _reassign(
            taskId: taskId, newAssigneeId: assigneeId, actorId: actor))
        .failureOrNull;
  }

  /// Возвращает новый статус или ошибку.
  Future<Either<Failure, TaskStatus>> undo() async {
    final actor = _session.state;
    if (actor == null) return const Left(SessionCubit.noUserFailure);
    return _undo(taskId: taskId, actorId: actor);
  }

  Future<Failure?> moveToTrash() async =>
      (await _trash(taskId)).failureOrNull;

  Future<List<UserEntity>> loadMembers(int projectId) async =>
      (await _getMembers(projectId)).getOrElse(() => const []);
}
