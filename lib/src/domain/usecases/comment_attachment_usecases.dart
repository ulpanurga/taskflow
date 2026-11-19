import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/other_repositories.dart';
import 'package:taskflow/src/domain/repositories/task_repository.dart';

class WatchComments {
  final CommentRepository _repo;
  const WatchComments(this._repo);

  Stream<Either<Failure, List<CommentEntity>>> call(int taskId) =>
      _repo.watchComments(taskId);
}

class AddComment {
  final CommentRepository _comments;
  final TaskRepository _tasks;
  const AddComment(this._comments, this._tasks);

  Future<Either<Failure, int>> call(
      {required int taskId,
      required int authorId,
      required String body}) async {
    if (body.trim().isEmpty) {
      return const Left(ValidationFailure('Комментарий не может быть пустым'));
    }
    final task = await _tasks.getTask(taskId);
    return task.thenAsync<int>((found) async {
      if (found == null) {
        return const Left(ValidationFailure(
            'Нельзя добавить комментарий к несуществующей задаче'));
      }
      return _comments.addComment(
          taskId: taskId, authorId: authorId, body: body.trim());
    });
  }
}

/// Удалять комментарий может только его автор.
class DeleteComment {
  final CommentRepository _repo;
  const DeleteComment(this._repo);

  Future<Either<Failure, Unit>> call(
      {required int commentId, required int currentUserId}) async {
    final result = await _repo.getComment(commentId);
    return result.thenAsync<Unit>((comment) async {
      if (comment == null) return const Right(unit);
      if (comment.authorId != currentUserId) {
        return const Left(ValidationFailure(
            'Удалять комментарий может только его автор'));
      }
      return _repo.deleteComment(commentId);
    });
  }
}

class WatchAttachments {
  final AttachmentRepository _repo;
  const WatchAttachments(this._repo);

  Stream<Either<Failure, List<AttachmentEntity>>> call(int taskId) =>
      _repo.watchAttachments(taskId);
}

class AddAttachment {
  final AttachmentRepository _attachments;
  final TaskRepository _tasks;
  const AddAttachment(this._attachments, this._tasks);

  Future<Either<Failure, int>> call(
      {required int taskId,
      required String fileName,
      required String filePath}) async {
    if (fileName.trim().isEmpty || filePath.trim().isEmpty) {
      return const Left(ValidationFailure('Не указан файл'));
    }
    final task = await _tasks.getTask(taskId);
    return task.thenAsync<int>((found) async {
      if (found == null) {
        return const Left(ValidationFailure('Задача не найдена'));
      }
      return _attachments.addAttachment(
          taskId: taskId, fileName: fileName, filePath: filePath);
    });
  }
}

class DeleteAttachment {
  final AttachmentRepository _repo;
  const DeleteAttachment(this._repo);

  Future<Either<Failure, Unit>> call(int id) => _repo.deleteAttachment(id);
}
