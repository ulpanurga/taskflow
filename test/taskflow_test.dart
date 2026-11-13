import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/models/enums.dart';
import 'package:taskflow/models/exceptions.dart';
import 'package:taskflow/models/views.dart';
import 'package:taskflow/repositories/comment_repository.dart';
import 'package:taskflow/repositories/project_repository.dart';
import 'package:taskflow/repositories/stats_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';
import 'package:taskflow/repositories/user_repository.dart';

void main() {
  late AppDatabase db;
  late UserRepository users;
  late ProjectRepository projects;
  late TaskRepository tasks;
  late CommentRepository comments;
  late StatsRepository stats;

  setUp(() {
    db = AppDatabase.memory();
    users = UserRepository(db);
    projects = ProjectRepository(db);
    tasks = TaskRepository(db);
    comments = CommentRepository(db);
    stats = StatsRepository(db);
  });

  tearDown(() async => db.close());

  /// Вспомогательная функция: проект + пользователь-участник.
  Future<({int project, int user})> setup() async {
    final u = await users.create('Анна', 'anna@mail.com');
    final p = await projects.create(name: 'Проект А');
    await projects.addMember(p, u, role: MemberRole.owner);
    return (project: p, user: u);
  }

  group('Пользователи', () {
    test('1. Создание и удаление пользователя', () async {
      final id = await users.create('Иван', 'ivan@mail.com');
      expect((await users.getAll()).length, 1);
      await users.delete(id);
      expect(await users.getAll(), isEmpty);
    });

    test('2. Email должен быть уникальным', () async {
      await users.create('Иван', 'ivan@mail.com');
      expect(() => users.create('Другой', 'IVAN@mail.com'),
          throwsA(isA<ValidationException>()));
    });

    test('3. Уникальность email гарантирует и сама база (UNIQUE)', () async {
      await users.create('Иван', 'ivan@mail.com');
      expect(
        () => db.into(db.users).insert(
            UsersCompanion.insert(name: 'Копия', email: 'ivan@mail.com')),
        throwsA(isA<Exception>()),
      );
    });

    test('4. Нельзя удалить пользователя с незавершёнными задачами', () async {
      final s = await setup();
      await tasks.createTask(
          projectId: s.project, title: 'Задача', assigneeId: s.user, actorId: s.user);
      expect(() => users.delete(s.user), throwsA(isA<ValidationException>()));
    });
  });

  group('Проекты и участники', () {
    test('5. Создание проекта', () async {
      final id = await projects.create(name: 'Новый', description: 'Описание');
      final p = await projects.getById(id);
      expect(p!.name, 'Новый');
      expect(p.status, ProjectStatus.active);
    });

    test('6. Добавление участника и повторное добавление запрещено', () async {
      final s = await setup();
      expect(await projects.isMember(s.project, s.user), isTrue);
      expect(() => projects.addMember(s.project, s.user),
          throwsA(isA<ValidationException>()));
    });

    test('7. Удаление проекта каскадно удаляет задачи', () async {
      final s = await setup();
      final t = await tasks.createTask(
          projectId: s.project, title: 'Т', actorId: s.user);
      await projects.delete(s.project);
      expect(await tasks.getById(t), isNull);
      expect(await tasks.getHistory(t), isEmpty);
    });
  });

  group('Задачи', () {
    test('8. Создание задачи пишет первую запись в историю', () async {
      final s = await setup();
      final id = await tasks.createTask(
          projectId: s.project, title: 'Первая', actorId: s.user);
      final history = await tasks.getHistory(id);
      expect(history.length, 1);
      expect(history.first.action, HistoryAction.created);
      expect(history.first.oldStatus, isNull);
      expect(history.first.newStatus, TaskStatus.todo);
    });

    test('9. Транзакция: ошибка в истории отменяет сохранение задачи', () async {
      final s = await setup();
      // actorId 9999 не существует — вставка истории нарушит внешний ключ
      await expectLater(
        tasks.createTask(projectId: s.project, title: 'Т', actorId: 9999),
        throwsA(anything),
      );
      expect(await tasks.count(const TaskFilter()), 0);
    });

    test('10. Исполнитель должен быть участником проекта', () async {
      final s = await setup();
      final outsider = await users.create('Чужой', 'out@mail.com');
      expect(
        () => tasks.createTask(
            projectId: s.project,
            title: 'Т',
            assigneeId: outsider,
            actorId: s.user),
        throwsA(isA<ValidationException>()),
      );
    });

    test('11. Нельзя создать задачу без проекта', () async {
      final s = await setup();
      expect(() => tasks.createTask(projectId: null, title: 'Т', actorId: s.user),
          throwsA(isA<ValidationException>()));
    });

    test('12. Смена статуса сохраняет историю', () async {
      final s = await setup();
      final id = await tasks.createTask(
          projectId: s.project, title: 'Т', actorId: s.user);
      await tasks.changeStatus(id, TaskStatus.inProgress, s.user);
      await tasks.changeStatus(id, TaskStatus.done, s.user);
      final h = await tasks.getHistory(id);
      expect(h.length, 3);
      expect(h[1].oldStatus, TaskStatus.todo);
      expect(h[1].newStatus, TaskStatus.inProgress);
      expect(h[2].newStatus, TaskStatus.done);
      expect(h[2].changedBy, s.user);
    });

    test('13. Переназначение атомарно: при ошибке ничего не меняется', () async {
      final s = await setup();
      final outsider = await users.create('Чужой', 'out@mail.com');
      final id = await tasks.createTask(
          projectId: s.project, title: 'Т', assigneeId: s.user, actorId: s.user);
      await expectLater(tasks.reassign(id, outsider, s.user),
          throwsA(isA<ValidationException>()));
      expect((await tasks.getById(id))!.assigneeId, s.user);
      expect((await tasks.getHistory(id)).length, 1);
    });

    test('14. Успешное переназначение пишет событие в историю', () async {
      final s = await setup();
      final bob = await users.create('Боб', 'bob@mail.com');
      await projects.addMember(s.project, bob);
      final id = await tasks.createTask(
          projectId: s.project, title: 'Т', assigneeId: s.user, actorId: s.user);
      await tasks.reassign(id, bob, s.user);
      expect((await tasks.getById(id))!.assigneeId, bob);
      final h = await tasks.getHistory(id);
      expect(h.last.action, HistoryAction.reassigned);
      expect(h.last.note, contains('Боб'));
    });

    test('15. Undo возвращает предыдущий статус', () async {
      final s = await setup();
      final id = await tasks.createTask(
          projectId: s.project, title: 'Т', actorId: s.user);
      await tasks.changeStatus(id, TaskStatus.inProgress, s.user);
      final restored = await tasks.undoLastStatusChange(id, s.user);
      expect(restored, TaskStatus.todo);
      expect((await tasks.getById(id))!.status, TaskStatus.todo);
      // второй Undo невозможен — отменять больше нечего
      expect(() => tasks.undoLastStatusChange(id, s.user),
          throwsA(isA<ValidationException>()));
    });

    test('16. Лимит: не более 3 незавершённых задач на один дедлайн', () async {
      final s = await setup();
      final day = DateTime(2030, 5, 10, 12);
      for (var i = 0; i < 3; i++) {
        await tasks.createTask(
            projectId: s.project,
            title: 'Т$i',
            assigneeId: s.user,
            deadline: day,
            actorId: s.user);
      }
      expect(
        () => tasks.createTask(
            projectId: s.project,
            title: 'Четвёртая',
            assigneeId: s.user,
            deadline: DateTime(2030, 5, 10, 18),
            actorId: s.user),
        throwsA(isA<ValidationException>()),
      );
      // на другой день — можно
      await tasks.createTask(
          projectId: s.project,
          title: 'Другой день',
          assigneeId: s.user,
          deadline: DateTime(2030, 5, 11),
          actorId: s.user);
    });
  });

  group('Комментарии', () {
    test('17. Добавление, проверка задачи и удаление только автором', () async {
      final s = await setup();
      final other = await users.create('Другой', 'other@mail.com');
      final t = await tasks.createTask(
          projectId: s.project, title: 'Т', actorId: s.user);

      final c = await comments.add(t, s.user, 'Привет');
      expect((await comments.getForTask(t)).length, 1);

      expect(() => comments.add(9999, s.user, 'в никуда'),
          throwsA(isA<ValidationException>()));
      expect(() => comments.delete(c, other),
          throwsA(isA<ValidationException>()));
      await comments.delete(c, s.user);
      expect(await comments.getForTask(t), isEmpty);
    });
  });

  group('Корзина', () {
    test('18. Soft Delete, восстановление и полное удаление', () async {
      final s = await setup();
      final id = await tasks.createTask(
          projectId: s.project, title: 'Т', actorId: s.user);

      await tasks.softDelete(id);
      expect(await tasks.count(const TaskFilter()), 0);
      expect(await tasks.count(const TaskFilter(onlyDeleted: true)), 1);
      // физически запись осталась в базе
      expect(await tasks.getById(id), isNotNull);

      await tasks.restore(id, s.user);
      expect(await tasks.count(const TaskFilter()), 1);
      expect(await tasks.count(const TaskFilter(onlyDeleted: true)), 0);

      // полное удаление только из корзины
      expect(() => tasks.deletePermanently(id),
          throwsA(isA<ValidationException>()));
      await tasks.softDelete(id);
      await tasks.deletePermanently(id);
      expect(await tasks.getById(id), isNull);
    });
  });

  group('Статистика, фильтры, миграции', () {
    test('19. Статистика считается правильно', () async {
      final s = await setup();
      final past = DateTime.now().subtract(const Duration(days: 3));
      final a = await tasks.createTask(
          projectId: s.project,
          title: 'A',
          assigneeId: s.user,
          priority: TaskPriority.high,
          deadline: past,
          actorId: s.user);
      final b = await tasks.createTask(
          projectId: s.project,
          title: 'B',
          assigneeId: s.user,
          priority: TaskPriority.low,
          actorId: s.user);
      await tasks.createTask(
          projectId: s.project, title: 'C', actorId: s.user);
      await tasks.changeStatus(b, TaskStatus.done, s.user);

      final r = await stats.load();
      expect(r.projects, 1);
      expect(r.tasks, 3);
      expect(r.done, 1);
      expect(r.notDone, 2);
      expect(r.overdue, 1); // только A: открыта и дедлайн в прошлом
      expect(r.byPriority[TaskPriority.high], 1);
      expect(r.byPriority[TaskPriority.low], 1);
      expect(r.byPriority[TaskPriority.medium], 1);
      expect(r.byAssignee.single.count, 2);
      expect(r.projectProgress.single.percent, closeTo(33.3, 0.1));
      expect(a, isPositive);
    });

    test('20. Фильтрация, поиск, сортировка и пагинация', () async {
      final s = await setup();
      for (var i = 0; i < 12; i++) {
        await tasks.createTask(
          projectId: s.project,
          title: i.isEven ? 'Отчёт $i' : 'Тест $i',
          description: i == 3 ? 'нужен срочный релиз' : '',
          priority: i < 4 ? TaskPriority.critical : TaskPriority.low,
          deadline: DateTime(2031, 1, 1 + i),
          actorId: s.user,
        );
      }
      expect(
          (await tasks.fetchTasks(const TaskFilter(query: 'Отчёт'))).length, 6);
      expect(
          (await tasks.fetchTasks(const TaskFilter(query: 'релиз'))).length, 1);
      expect(
          (await tasks.fetchTasks(
                  const TaskFilter(priority: TaskPriority.critical)))
              .length,
          4);
      expect((await tasks.fetchTasks(const TaskFilter(status: TaskStatus.done))),
          isEmpty);

      final byDeadline = await tasks.fetchTasks(
          const TaskFilter(sortBy: TaskSort.deadline, ascending: true));
      expect(byDeadline.first.task.deadline, DateTime(2031, 1, 1));

      final page1 = await tasks.fetchTasks(const TaskFilter(limit: 5));
      final page3 = await tasks.fetchTasks(const TaskFilter(limit: 5, offset: 10));
      expect(page1.length, 5);
      expect(page3.length, 2);
    });

    test('21. Миграция v1 -> v2: поле priority, старые данные сохраняются',
        () async {
      final dir = Directory.systemTemp.createTempSync('taskflow_mig');
      final file = File('${dir.path}/old.sqlite');

      // Создаём базу первой версии: таблица tasks БЕЗ поля priority
      final raw = sql.sqlite3.open(file.path);
      raw.execute('''
        CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          project_id INTEGER NOT NULL,
          assignee_id INTEGER,
          status TEXT NOT NULL DEFAULT 'todo',
          deadline INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      raw.execute(
          "INSERT INTO tasks (title, project_id, status, created_at, updated_at) "
          "VALUES ('Старая 1', 1, 'todo', 1700000000, 1700000000), "
          "('Старая 2', 1, 'done', 1700000000, 1700000000)");
      raw.execute('PRAGMA user_version = 1');
      raw.dispose();

      // Открываем через Drift (версия 2) — запускается миграция
      final migrated = AppDatabase(NativeDatabase(file));
      final rows = await migrated.customSelect(
          'SELECT title, priority, status FROM tasks ORDER BY id').get();

      expect(rows.length, 2); // данные не потеряны
      expect(rows[0].read<String>('title'), 'Старая 1');
      expect(rows[0].read<String>('priority'), 'medium');
      expect(rows[1].read<String>('priority'), 'medium');
      expect(rows[1].read<String>('status'), 'done');

      await migrated.close();
      dir.deleteSync(recursive: true);
    });
  });
}
