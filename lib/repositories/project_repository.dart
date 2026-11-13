import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/exceptions.dart';
import '../models/views.dart';

class ProjectRepository {
  final AppDatabase _db;
  ProjectRepository(this._db);

  Future<int> create({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? finishedAt,
  }) {
    if (name.trim().isEmpty) {
      throw const ValidationException('Название проекта не может быть пустым');
    }
    return _db.into(_db.projects).insert(ProjectsCompanion.insert(
          name: name.trim(),
          description: Value(description),
          status: Value(status),
          finishedAt: Value(finishedAt),
        ));
  }

  Future<void> update(
    int id, {
    required String name,
    String description = '',
    required ProjectStatus status,
    DateTime? finishedAt,
  }) async {
    if (name.trim().isEmpty) {
      throw const ValidationException('Название проекта не может быть пустым');
    }
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(name.trim()),
        description: Value(description),
        status: Value(status),
        finishedAt: Value(finishedAt),
      ),
    );
  }

  /// Удаление проекта каскадно удаляет участников, задачи,
  /// комментарии, вложения и историю (ON DELETE CASCADE).
  Future<void> delete(int id) async {
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
  }

  Stream<List<Project>> watchAll() {
    return (_db.select(_db.projects)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<List<Project>> getAll() => _db.select(_db.projects).get();

  Future<Project?> getById(int id) {
    return (_db.select(_db.projects)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  // ---------- Участники ----------

  Future<int> addMember(int projectId, int userId,
      {MemberRole role = MemberRole.member}) async {
    final project = await getById(projectId);
    if (project == null) {
      throw const ValidationException('Проект не найден');
    }
    final user = await (_db.select(_db.users)..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    if (user == null) {
      throw const ValidationException('Пользователь не найден');
    }
    if (await isMember(projectId, userId)) {
      throw const ValidationException('Пользователь уже состоит в проекте');
    }
    return _db.into(_db.projectMembers).insert(ProjectMembersCompanion.insert(
          projectId: projectId,
          userId: userId,
          role: Value(role),
        ));
  }

  /// Нельзя убрать участника, пока у него есть незавершённые задачи проекта.
  Future<void> removeMember(int projectId, int userId) async {
    final c = _db.tasks.id.count();
    final q = _db.selectOnly(_db.tasks)
      ..addColumns([c])
      ..where(_db.tasks.projectId.equals(projectId) &
          _db.tasks.assigneeId.equals(userId) &
          _db.tasks.status.isIn([TaskStatus.todo.name, TaskStatus.inProgress.name]) &
          _db.tasks.deletedAt.isNull());
    final open = (await q.getSingle()).read(c) ?? 0;
    if (open > 0) {
      throw ValidationException(
          'У участника $open незавершённых задач в проекте. Сначала переназначьте их.');
    }
    await (_db.delete(_db.projectMembers)
          ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .go();
  }

  Future<void> setRole(int projectId, int userId, MemberRole role) async {
    await (_db.update(_db.projectMembers)
          ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .write(ProjectMembersCompanion(role: Value(role)));
  }

  Future<bool> isMember(int projectId, int userId) async {
    final rows = await (_db.select(_db.projectMembers)
          ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .get();
    return rows.isNotEmpty;
  }

  Stream<List<MemberView>> watchMembers(int projectId) {
    final q = _db.select(_db.projectMembers).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.projectMembers.userId)),
    ])
      ..where(_db.projectMembers.projectId.equals(projectId))
      ..orderBy([OrderingTerm.asc(_db.users.name)]);
    return q.watch().map((rows) => rows
        .map((r) => MemberView(
              r.readTable(_db.projectMembers),
              r.readTable(_db.users),
            ))
        .toList());
  }

  Future<List<User>> getMembers(int projectId) async {
    final q = _db.select(_db.users).join([
      innerJoin(_db.projectMembers,
          _db.projectMembers.userId.equalsExp(_db.users.id)),
    ])
      ..where(_db.projectMembers.projectId.equals(projectId));
    return (await q.get()).map((r) => r.readTable(_db.users)).toList();
  }
}
