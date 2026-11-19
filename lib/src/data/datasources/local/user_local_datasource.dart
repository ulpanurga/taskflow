import 'package:drift/drift.dart';
import 'package:taskflow/src/data/datasources/local/app_database.dart';
import 'package:taskflow/src/domain/entities/enums.dart';

/// Работа с таблицей users. Здесь только SQL, никаких бизнес-правил.
class UserLocalDataSource {
  final AppDatabase _db;
  UserLocalDataSource(this._db);

  Stream<List<User>> watchAll() {
    return (_db.select(_db.users)..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .watch();
  }

  Future<List<User>> getAll() {
    return (_db.select(_db.users)..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .get();
  }

  Future<int> insert(String name, String email) {
    return _db
        .into(_db.users)
        .insert(UsersCompanion.insert(name: name, email: email));
  }

  Future<void> update(int id, String name, String email) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(name: Value(name), email: Value(email)),
    );
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();
  }

  Future<bool> emailExists(String email, {int? exceptId}) async {
    final rows = await (_db.select(_db.users)
          ..where((u) => u.email.equals(email.trim().toLowerCase())))
        .get();
    return rows.any((u) => u.id != exceptId);
  }

  Future<int> countOpenTasks(int userId) async {
    final c = _db.tasks.id.count();
    final q = _db.selectOnly(_db.tasks)
      ..addColumns([c])
      ..where(_db.tasks.assigneeId.equals(userId) &
          _db.tasks.status
              .isIn([TaskStatus.todo.name, TaskStatus.inProgress.name]) &
          _db.tasks.deletedAt.isNull());
    return (await q.getSingle()).read(c) ?? 0;
  }
}
