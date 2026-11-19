import 'package:drift/drift.dart';
import 'package:taskflow/src/data/datasources/local/app_database.dart';
import 'package:taskflow/src/domain/entities/enums.dart';

/// Участник проекта вместе с пользователем (результат JOIN).
class MemberRow {
  final ProjectMember member;
  final User user;
  const MemberRow(this.member, this.user);
}

/// Таблицы projects и project_members.
class ProjectLocalDataSource {
  final AppDatabase _db;
  ProjectLocalDataSource(this._db);

  Stream<List<Project>> watchAll() {
    return (_db.select(_db.projects)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<List<Project>> getAll() {
    return (_db.select(_db.projects)
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  Future<int> insert({
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) {
    return _db.into(_db.projects).insert(ProjectsCompanion.insert(
          name: name,
          description: Value(description),
          status: Value(status),
          finishedAt: Value(finishedAt),
        ));
  }

  Future<void> update({
    required int id,
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) async {
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(name),
        description: Value(description),
        status: Value(status),
        finishedAt: Value(finishedAt),
      ),
    );
  }

  /// Задачи, комментарии, вложения и история удаляются каскадом.
  Future<void> delete(int id) async {
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
  }

  // ---------- Участники ----------

  Stream<List<MemberRow>> watchMembers(int projectId) {
    final q = _db.select(_db.projectMembers).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.projectMembers.userId)),
    ])
      ..where(_db.projectMembers.projectId.equals(projectId))
      ..orderBy([OrderingTerm.asc(_db.users.name)]);
    return q.watch().map((rows) => rows
        .map((r) =>
            MemberRow(r.readTable(_db.projectMembers), r.readTable(_db.users)))
        .toList());
  }

  Future<List<User>> getMemberUsers(int projectId) async {
    final q = _db.select(_db.users).join([
      innerJoin(_db.projectMembers,
          _db.projectMembers.userId.equalsExp(_db.users.id)),
    ])
      ..where(_db.projectMembers.projectId.equals(projectId))
      ..orderBy([OrderingTerm.asc(_db.users.name)]);
    return (await q.get()).map((r) => r.readTable(_db.users)).toList();
  }

  Future<void> addMember(int projectId, int userId, MemberRole role) async {
    await _db.into(_db.projectMembers).insert(ProjectMembersCompanion.insert(
          projectId: projectId,
          userId: userId,
          role: Value(role),
        ));
  }

  Future<void> removeMember(int projectId, int userId) async {
    await (_db.delete(_db.projectMembers)
          ..where(
              (m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .go();
  }

  Future<void> setRole(int projectId, int userId, MemberRole role) async {
    await (_db.update(_db.projectMembers)
          ..where(
              (m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .write(ProjectMembersCompanion(role: Value(role)));
  }

  Future<bool> isMember(int projectId, int userId) async {
    final rows = await (_db.select(_db.projectMembers)
          ..where(
              (m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .get();
    return rows.isNotEmpty;
  }

  Future<int> countOpenTasksOfMember(int projectId, int userId) async {
    final c = _db.tasks.id.count();
    final q = _db.selectOnly(_db.tasks)
      ..addColumns([c])
      ..where(_db.tasks.projectId.equals(projectId) &
          _db.tasks.assigneeId.equals(userId) &
          _db.tasks.status
              .isIn([TaskStatus.todo.name, TaskStatus.inProgress.name]) &
          _db.tasks.deletedAt.isNull());
    return (await q.getSingle()).read(c) ?? 0;
  }
}
