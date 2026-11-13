import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/exceptions.dart';
import '../models/views.dart';

class CommentRepository {
  final AppDatabase _db;
  CommentRepository(this._db);

  Future<int> add(int taskId, int authorId, String body) async {
    if (body.trim().isEmpty) {
      throw const ValidationException('Комментарий не может быть пустым');
    }
    final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
    if (task == null) {
      throw const ValidationException(
          'Нельзя добавить комментарий к несуществующей задаче');
    }
    final author =
        await (_db.select(_db.users)..where((u) => u.id.equals(authorId)))
            .getSingleOrNull();
    if (author == null) {
      throw const ValidationException('Автор не найден');
    }
    return _db.into(_db.comments).insert(CommentsCompanion.insert(
          body: body.trim(),
          authorId: authorId,
          taskId: taskId,
        ));
  }

  /// Удалять комментарий может только его автор.
  Future<void> delete(int commentId, int currentUserId) async {
    final c = await (_db.select(_db.comments)
          ..where((c) => c.id.equals(commentId)))
        .getSingleOrNull();
    if (c == null) return;
    if (c.authorId != currentUserId) {
      throw const ValidationException(
          'Удалять комментарий может только его автор');
    }
    await (_db.delete(_db.comments)..where((c) => c.id.equals(commentId))).go();
  }

  Stream<List<CommentView>> watchForTask(int taskId) {
    final q = _db.select(_db.comments).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.comments.authorId)),
    ])
      ..where(_db.comments.taskId.equals(taskId))
      ..orderBy([OrderingTerm.asc(_db.comments.createdAt)]);
    return q.watch().map((rows) => rows
        .map((r) => CommentView(r.readTable(_db.comments), r.readTable(_db.users)))
        .toList());
  }

  Future<List<Comment>> getForTask(int taskId) {
    return (_db.select(_db.comments)..where((c) => c.taskId.equals(taskId)))
        .get();
  }
}
