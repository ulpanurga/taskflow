import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/exceptions.dart';

class UserRepository {
  final AppDatabase _db;
  UserRepository(this._db);

  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _validate(String name, String email) {
    if (name.trim().isEmpty) {
      throw const ValidationException('Имя не может быть пустым');
    }
    if (!_emailRegExp.hasMatch(email.trim())) {
      throw const ValidationException('Некорректный email');
    }
  }

  Future<bool> _emailTaken(String email, {int? exceptId}) async {
    final q = _db.select(_db.users)
      ..where((u) => u.email.equals(email.trim().toLowerCase()));
    final rows = await q.get();
    return rows.any((u) => u.id != exceptId);
  }

  Future<int> create(String name, String email) async {
    _validate(name, email);
    if (await _emailTaken(email)) {
      throw const ValidationException('Пользователь с таким email уже есть');
    }
    return _db.into(_db.users).insert(UsersCompanion.insert(
          name: name.trim(),
          email: email.trim().toLowerCase(),
        ));
  }

  Future<void> update(int id, String name, String email) async {
    _validate(name, email);
    if (await _emailTaken(email, exceptId: id)) {
      throw const ValidationException('Пользователь с таким email уже есть');
    }
    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        name: Value(name.trim()),
        email: Value(email.trim().toLowerCase()),
      ),
    );
  }

  /// Нельзя удалить пользователя, если за ним закреплены незавершённые задачи.
  Future<void> delete(int id) async {
    final open = await countOpenTasks(id);
    if (open > 0) {
      throw ValidationException(
          'Нельзя удалить: у пользователя $open незавершённых задач');
    }
    await (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();
  }

  Future<int> countOpenTasks(int userId) async {
    final c = _db.tasks.id.count();
    final q = _db.selectOnly(_db.tasks)
      ..addColumns([c])
      ..where(_db.tasks.assigneeId.equals(userId) &
          _db.tasks.status.isIn([TaskStatus.todo.name, TaskStatus.inProgress.name]) &
          _db.tasks.deletedAt.isNull());
    return (await q.getSingle()).read(c) ?? 0;
  }

  Stream<List<User>> watchAll() {
    return (_db.select(_db.users)..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .watch();
  }

  Future<List<User>> getAll() => _db.select(_db.users).get();

  Future<User?> getById(int id) {
    return (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
  }
}
