import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/dashboard_stats_entity.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';

abstract class CommentRepository {
  Stream<Either<Failure, List<CommentEntity>>> watchComments(int taskId);

  /// Right(null), если комментария нет.
  Future<Either<Failure, CommentEntity?>> getComment(int id);
  Future<Either<Failure, int>> addComment(
      {required int taskId, required int authorId, required String body});
  Future<Either<Failure, Unit>> deleteComment(int id);
}

abstract class AttachmentRepository {
  Stream<Either<Failure, List<AttachmentEntity>>> watchAttachments(int taskId);
  Future<Either<Failure, int>> addAttachment(
      {required int taskId, required String fileName, required String filePath});
  Future<Either<Failure, Unit>> deleteAttachment(int id);
}

abstract class StatsRepository {
  Stream<Either<Failure, DashboardStatsEntity>> watchStats();
}

/// Задачи, которые лежат на сервере.
abstract class RemoteTodoRepository {
  Future<Either<Failure, List<RemoteTodo>>> fetchTodos({required int limit});
}
