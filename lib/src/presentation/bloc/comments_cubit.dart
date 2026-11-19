import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/usecases/comment_attachment_usecases.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

class CommentsCubit extends WatchCubit<List<CommentEntity>> {
  final int taskId;
  final WatchComments _watch;
  final AddComment _add;
  final DeleteComment _delete;
  final SessionCubit _session;

  CommentsCubit(this.taskId, this._watch, this._add, this._delete, this._session);

  @override
  Stream<Either<Failure, List<CommentEntity>>> watchSource() => _watch(taskId);

  Future<Failure?> add(String body) async {
    final actor = _session.state;
    if (actor == null) return SessionCubit.noUserFailure;
    return (await _add(taskId: taskId, authorId: actor, body: body))
        .failureOrNull;
  }

  Future<Failure?> delete(int commentId) async {
    final actor = _session.state;
    if (actor == null) return SessionCubit.noUserFailure;
    return (await _delete(commentId: commentId, currentUserId: actor))
        .failureOrNull;
  }
}
