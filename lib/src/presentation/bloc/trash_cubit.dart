import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

/// Корзина: задачи с deletedAt != null.
class TrashCubit extends WatchCubit<List<TaskEntity>> {
  final WatchTasks _watch;
  final RestoreTask _restore;
  final DeleteTaskPermanently _deleteForever;
  final SessionCubit _session;

  TrashCubit(this._watch, this._restore, this._deleteForever, this._session);

  @override
  Stream<Either<Failure, List<TaskEntity>>> watchSource() =>
      _watch(const TaskFilterEntity(onlyDeleted: true, limit: 500));

  Future<Failure?> restore(int taskId) async {
    final actor = _session.state;
    if (actor == null) return SessionCubit.noUserFailure;
    return (await _restore(taskId: taskId, actorId: actor)).failureOrNull;
  }

  Future<Failure?> deleteForever(int taskId) async =>
      (await _deleteForever(taskId)).failureOrNull;
}
