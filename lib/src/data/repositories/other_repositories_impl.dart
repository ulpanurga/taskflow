import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/error_handler.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/data/datasources/local/other_local_datasources.dart';
import 'package:taskflow/src/data/datasources/remote/task_remote_datasource.dart';
import 'package:taskflow/src/data/mapper/mappers.dart';
import 'package:taskflow/src/data/repositories/local_repository.dart';
import 'package:taskflow/src/domain/entities/dashboard_stats_entity.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/other_repositories.dart';

class CommentRepositoryImpl extends LocalRepository
    implements CommentRepository {
  final CommentLocalDataSource _local;
  const CommentRepositoryImpl(this._local);

  @override
  Stream<Either<Failure, List<CommentEntity>>> watchComments(int taskId) =>
      watch(_local
          .watchForTask(taskId)
          .map((rows) => rows.map((r) => r.toEntity()).toList()));

  @override
  Future<Either<Failure, CommentEntity?>> getComment(int id) =>
      run<CommentEntity?>(() async => (await _local.getById(id))?.toEntity());

  @override
  Future<Either<Failure, int>> addComment(
          {required int taskId,
          required int authorId,
          required String body}) =>
      run(() => _local.insert(taskId, authorId, body));

  @override
  Future<Either<Failure, Unit>> deleteComment(int id) => run(() async {
        await _local.delete(id);
        return unit;
      });
}

class AttachmentRepositoryImpl extends LocalRepository
    implements AttachmentRepository {
  final AttachmentLocalDataSource _local;
  const AttachmentRepositoryImpl(this._local);

  @override
  Stream<Either<Failure, List<AttachmentEntity>>> watchAttachments(
          int taskId) =>
      watch(_local
          .watchForTask(taskId)
          .map((rows) => rows.map((a) => a.toEntity()).toList()));

  @override
  Future<Either<Failure, int>> addAttachment(
          {required int taskId,
          required String fileName,
          required String filePath}) =>
      run(() => _local.insert(taskId, fileName, filePath));

  @override
  Future<Either<Failure, Unit>> deleteAttachment(int id) => run(() async {
        await _local.delete(id);
        return unit;
      });
}

class StatsRepositoryImpl extends LocalRepository implements StatsRepository {
  final StatsLocalDataSource _local;
  const StatsRepositoryImpl(this._local);

  @override
  Stream<Either<Failure, DashboardStatsEntity>> watchStats() =>
      watch(_local.watch().map((model) => model.toEntity()));
}

/// Задачи с сервера. Ошибки сети и сервера превращаются в Failure здесь.
class RemoteTodoRepositoryImpl implements RemoteTodoRepository {
  final TaskRemoteDataSource _remote;
  const RemoteTodoRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<RemoteTodo>>> fetchTodos(
          {required int limit}) =>
      guardCall(() async {
        final models = await _remote.getTodos(limit: limit);
        return models.map((m) => m.toEntity()).toList();
      });
}
