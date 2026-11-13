import 'dart:math';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';

/// Заполняет базу тестовыми данными:
/// 1000 пользователей, 100 проектов, 10 000 задач.
class DataSeeder {
  final AppDatabase _db;
  DataSeeder(this._db);

  Future<void> seed({
    int users = 1000,
    int projects = 100,
    int tasks = 10000,
    int seed = 42,
  }) async {
    final rnd = Random(seed);
    final now = DateTime.now();

    // Пользователи
    await _db.batch((b) {
      b.insertAll(_db.users, [
        for (var i = 0; i < users; i++)
          UsersCompanion.insert(
            name: 'Пользователь $i',
            email: 'seed_${now.microsecondsSinceEpoch}_$i@example.com',
          ),
      ]);
    });
    final userIds = (await _db.select(_db.users).get()).map((u) => u.id).toList();
    final newUserIds = userIds.sublist(userIds.length - users);

    // Проекты
    await _db.batch((b) {
      b.insertAll(_db.projects, [
        for (var i = 0; i < projects; i++)
          ProjectsCompanion.insert(
            name: 'Проект $i',
            description: Value('Описание тестового проекта $i'),
          ),
      ]);
    });
    final projectIds =
        (await _db.select(_db.projects).get()).map((p) => p.id).toList();
    final newProjectIds = projectIds.sublist(projectIds.length - projects);

    // Участники: по 20 пользователей в каждом проекте
    final members = <int, List<int>>{};
    final memberRows = <ProjectMembersCompanion>[];
    for (final pid in newProjectIds) {
      final chosen = <int>{};
      while (chosen.length < min(20, newUserIds.length)) {
        chosen.add(newUserIds[rnd.nextInt(newUserIds.length)]);
      }
      members[pid] = chosen.toList();
      for (final uid in chosen) {
        memberRows.add(ProjectMembersCompanion.insert(
          projectId: pid,
          userId: uid,
          role: const Value(MemberRole.member),
        ));
      }
    }
    await _db.batch((b) => b.insertAll(_db.projectMembers, memberRows));

    // Задачи
    final words = ['отчёт', 'дизайн', 'тесты', 'релиз', 'баг', 'встреча', 'документ'];
    final taskRows = <TasksCompanion>[];
    for (var i = 0; i < tasks; i++) {
      final pid = newProjectIds[rnd.nextInt(newProjectIds.length)];
      final assignee = members[pid]![rnd.nextInt(members[pid]!.length)];
      final created = now.subtract(Duration(days: rnd.nextInt(180)));
      taskRows.add(TasksCompanion.insert(
        title: 'Задача $i: ${words[rnd.nextInt(words.length)]}',
        description: Value('Описание ${words[rnd.nextInt(words.length)]} $i'),
        projectId: pid,
        assigneeId: Value(assignee),
        priority: Value(TaskPriority.values[rnd.nextInt(4)]),
        status: Value(TaskStatus.values[rnd.nextInt(4)]),
        deadline: Value(now.add(Duration(days: rnd.nextInt(60) - 30))),
        createdAt: Value(created),
        updatedAt: Value(created),
      ));
    }
    await _db.batch((b) => b.insertAll(_db.tasks, taskRows));
  }
}
