import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';

import 'test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('Пользователи', () {
    test('1. Создание пользователя: email приводится к нижнему регистру',
        () async {
      ok(await env.createUser(name: ' Иван ', email: 'IVAN@Mail.com'));
      final users = ok(await env.userRepo.getUsers());
      expect(users.single.name, 'Иван');
      expect(users.single.email, 'ivan@mail.com');
    });

    test('2. Одинаковый email запрещён', () async {
      ok(await env.createUser(name: 'Иван', email: 'ivan@mail.com'));
      final f = bad(await env.createUser(name: 'Другой', email: 'IVAN@mail.com'));
      expect(f, isA<ValidationFailure>());
    });

    test('3. Неверный email и пустое имя', () async {
      expect(bad(await env.createUser(name: 'Иван', email: 'не-почта')),
          isA<ValidationFailure>());
      expect(bad(await env.createUser(name: '  ', email: 'a@b.com')),
          isA<ValidationFailure>());
    });

    test('4. Нельзя удалить пользователя с незавершёнными задачами', () async {
      final s = await env.basic();
      ok(await env.createTask(
          projectId: s.project, title: 'Т', assigneeId: s.user, actorId: s.user));
      expect(bad(await env.deleteUser(s.user)), isA<ValidationFailure>());
    });
  });

  group('Проекты и участники', () {
    test('5. Пустое название проекта запрещено', () async {
      expect(bad(await env.createProject(name: '  ')),
          isA<ValidationFailure>());
    });

    test('6. Повторное добавление участника запрещено', () async {
      final s = await env.basic();
      final f = bad(await env.addMember(projectId: s.project, userId: s.user));
      expect(f.message, contains('уже состоит'));
    });

    test('7. Нельзя убрать участника с незавершёнными задачами', () async {
      final s = await env.basic();
      ok(await env.createTask(
          projectId: s.project, title: 'Т', assigneeId: s.user, actorId: s.user));
      expect(bad(await env.removeMember(projectId: s.project, userId: s.user)),
          isA<ValidationFailure>());
    });

    test('8. Удаление проекта каскадно удаляет задачи и историю', () async {
      final s = await env.basic();
      final t = ok(await env.createTask(
          projectId: s.project, title: 'Т', actorId: s.user));
      ok(await env.deleteProject(s.project));
      expect(ok(await env.taskRepo.getTask(t)), isNull);
      expect(ok(await env.taskRepo.getHistory(t)), isEmpty);
    });
  });

  group('Задачи', () {
    test('9. Создание задачи пишет первую запись в историю', () async {
      final s = await env.basic();
      final id = ok(await env.createTask(
          projectId: s.project, title: 'Первая', actorId: s.user));
      final history = ok(await env.taskRepo.getHistory(id));
      expect(history.length, 1);
      expect(history.first.action, HistoryAction.created);
      expect(history.first.oldStatus, isNull);
    });

    test('10. Транзакция: ошибка в истории отменяет сохранение задачи',
        () async {
      final s = await env.basic();
      // Пользователя 9999 нет — запись истории нарушит внешний ключ.
      final result = await env.createTask(
          projectId: s.project, title: 'Т', actorId: 9999);
      expect(bad(result), isA<CacheFailure>());
      final tasks = ok(await env.taskRepo
          .watchTasks(const TaskFilterEntity())
          .first);
      expect(tasks, isEmpty);
    });

    test('11. Исполнитель должен быть участником проекта', () async {
      final s = await env.basic();
      final outsider =
          ok(await env.createUser(name: 'Чужой', email: 'out@mail.com'));
      final f = bad(await env.createTask(
          projectId: s.project,
          title: 'Т',
          assigneeId: outsider,
          actorId: s.user));
      expect(f, isA<ValidationFailure>());
    });

    test('12. Смена статуса пишет историю, одинаковый статус ничего не меняет',
        () async {
      final s = await env.basic();
      final id = ok(await env.createTask(
          projectId: s.project, title: 'Т', actorId: s.user));
      ok(await env.changeStatus(
          taskId: id, newStatus: TaskStatus.inProgress, actorId: s.user));
      ok(await env.changeStatus(
          taskId: id, newStatus: TaskStatus.inProgress, actorId: s.user));
      final h = ok(await env.taskRepo.getHistory(id));
      expect(h.length, 2);
      expect(h[1].oldStatus, TaskStatus.todo);
      expect(h[1].newStatus, TaskStatus.inProgress);
    });

    test('13. Переназначение: успех пишет историю, ошибка ничего не меняет',
        () async {
      final s = await env.basic();
      final bob = ok(await env.createUser(name: 'Боб', email: 'bob@mail.com'));
      final outsider =
          ok(await env.createUser(name: 'Чужой', email: 'out@mail.com'));
      ok(await env.addMember(projectId: s.project, userId: bob));
      final id = ok(await env.createTask(
          projectId: s.project, title: 'Т', assigneeId: s.user, actorId: s.user));

      expect(bad(await env.reassign(taskId: id, newAssigneeId: outsider, actorId: s.user)),
          isA<ValidationFailure>());
      expect(ok(await env.taskRepo.getTask(id))!.assigneeId, s.user);
      expect(ok(await env.taskRepo.getHistory(id)).length, 1);

      ok(await env.reassign(taskId: id, newAssigneeId: bob, actorId: s.user));
      expect(ok(await env.taskRepo.getTask(id))!.assigneeName, 'Боб');
      expect(ok(await env.taskRepo.getHistory(id)).last.note, contains('Боб'));
    });

    test('14. Undo возвращает прошлый статус, второй Undo невозможен',
        () async {
      final s = await env.basic();
      final id = ok(await env.createTask(
          projectId: s.project, title: 'Т', actorId: s.user));
      ok(await env.changeStatus(
          taskId: id, newStatus: TaskStatus.inProgress, actorId: s.user));

      final restored = ok(await env.undo(taskId: id, actorId: s.user));
      expect(restored, TaskStatus.todo);
      expect(ok(await env.taskRepo.getTask(id))!.status, TaskStatus.todo);
      expect(bad(await env.undo(taskId: id, actorId: s.user)),
          isA<ValidationFailure>());
    });

    test('15. Лимит: не больше 3 незавершённых задач на один день', () async {
      final s = await env.basic();
      for (var i = 0; i < 3; i++) {
        ok(await env.createTask(
            projectId: s.project,
            title: 'Т$i',
            assigneeId: s.user,
            deadline: DateTime(2031, 5, 10, 12),
            actorId: s.user));
      }
      final f = bad(await env.createTask(
          projectId: s.project,
          title: 'Четвёртая',
          assigneeId: s.user,
          deadline: DateTime(2031, 5, 10, 18),
          actorId: s.user));
      expect(f, isA<ValidationFailure>());

      // На другой день можно.
      ok(await env.createTask(
          projectId: s.project,
          title: 'Другой день',
          assigneeId: s.user,
          deadline: DateTime(2031, 5, 11),
          actorId: s.user));
    });

    test('16. Корзина: удалить, восстановить, удалить навсегда', () async {
      final s = await env.basic();
      final id = ok(await env.createTask(
          projectId: s.project, title: 'Т', actorId: s.user));

      ok(await env.trash(id));
      expect(
          ok(await env.taskRepo.watchTasks(const TaskFilterEntity()).first),
          isEmpty);
      expect(
          ok(await env.taskRepo
                  .watchTasks(const TaskFilterEntity(onlyDeleted: true))
                  .first)
              .length,
          1);

      ok(await env.restore(taskId: id, actorId: s.user));
      expect(
          ok(await env.taskRepo.watchTasks(const TaskFilterEntity()).first)
              .length,
          1);

      // Из корзины, а не из списка
      expect(bad(await env.deleteForever(id)), isA<ValidationFailure>());
      ok(await env.trash(id));
      ok(await env.deleteForever(id));
      expect(ok(await env.taskRepo.getTask(id)), isNull);
    });

    test('17. Фильтры, поиск, сортировка и пагинация', () async {
      final s = await env.basic();
      for (var i = 0; i < 12; i++) {
        ok(await env.createTask(
          projectId: s.project,
          title: i.isEven ? 'Отчёт $i' : 'Тест $i',
          description: i == 3 ? 'нужен срочный релиз' : '',
          priority: i < 4 ? TaskPriority.critical : TaskPriority.low,
          deadline: DateTime(2031, 1, 1 + i),
          actorId: s.user,
        ));
      }
      Future<List<TaskEntity>> load(TaskFilterEntity f) async =>
          ok(await env.taskRepo.watchTasks(f).first);

      expect((await load(const TaskFilterEntity(query: 'Отчёт'))).length, 6);
      expect((await load(const TaskFilterEntity(query: 'релиз'))).length, 1);
      expect(
          (await load(const TaskFilterEntity(priority: TaskPriority.critical)))
              .length,
          4);
      expect((await load(const TaskFilterEntity(status: TaskStatus.done))),
          isEmpty);

      final byDeadline = await load(const TaskFilterEntity(
          sortBy: TaskSort.deadline, ascending: true));
      expect(byDeadline.first.deadline, DateTime(2031, 1, 1));

      expect((await load(const TaskFilterEntity(limit: 5))).length, 5);
      expect((await load(const TaskFilterEntity(limit: 5, offset: 10))).length, 2);
    });
  });

  group('Комментарии и статистика', () {
    test('18. Комментарии: только автор удаляет, к чужой задаче нельзя',
        () async {
      final s = await env.basic();
      final other =
          ok(await env.createUser(name: 'Другой', email: 'other@mail.com'));
      final t = ok(await env.createTask(
          projectId: s.project, title: 'Т', actorId: s.user));

      final c = ok(await env.addComment(taskId: t, authorId: s.user, body: 'Привет'));
      expect(bad(await env.addComment(taskId: 9999, authorId: s.user, body: 'x')),
          isA<ValidationFailure>());
      expect(bad(await env.addComment(taskId: t, authorId: s.user, body: '  ')),
          isA<ValidationFailure>());
      expect(bad(await env.deleteComment(commentId: c, currentUserId: other)),
          isA<ValidationFailure>());
      ok(await env.deleteComment(commentId: c, currentUserId: s.user));
      expect(ok(await env.commentRepo.getComment(c)), isNull);
    });

    test('19. Статистика считается правильно', () async {
      final s = await env.basic();
      final past = DateTime.now().subtract(const Duration(days: 3));
      ok(await env.createTask(
          projectId: s.project,
          title: 'A',
          assigneeId: s.user,
          priority: TaskPriority.high,
          deadline: past,
          actorId: s.user));
      final b = ok(await env.createTask(
          projectId: s.project,
          title: 'B',
          assigneeId: s.user,
          priority: TaskPriority.low,
          actorId: s.user));
      ok(await env.createTask(projectId: s.project, title: 'C', actorId: s.user));
      ok(await env.changeStatus(
          taskId: b, newStatus: TaskStatus.done, actorId: s.user));

      final r = ok(await env.statsRepo.watchStats().first);
      expect(r.projects, 1);
      expect(r.tasks, 3);
      expect(r.done, 1);
      expect(r.notDone, 2);
      expect(r.overdue, 1);
      expect(r.byPriority[TaskPriority.high], 1);
      expect(r.byPriority[TaskPriority.medium], 1);
      expect(r.byAssignee.single.count, 2);
      expect(r.projectProgress.single.percent, closeTo(33.3, 0.1));
    });
  });

  group('Импорт с сервера (локальное сохранение)', () {
    test('20. Импортированные задачи сохраняются в базу, дубли пропускаются',
        () async {
      final s = await env.basic();
      const todos = [
        RemoteTodo(id: 1, title: 'Купить хлеб', completed: false),
        RemoteTodo(id: 2, title: 'Сделать СРС', completed: true),
      ];

      final added = ok(await env.importTodos(
          projectId: s.project, actorId: s.user, todos: todos));
      expect(added, 2);

      final tasks =
          ok(await env.taskRepo.watchTasks(const TaskFilterEntity()).first);
      expect(tasks.length, 2);
      expect(tasks.firstWhere((t) => t.title == 'Сделать СРС').status,
          TaskStatus.done);
      expect(tasks.firstWhere((t) => t.title == 'Купить хлеб').status,
          TaskStatus.todo);
      // у каждой задачи есть запись истории
      for (final t in tasks) {
        expect(ok(await env.taskRepo.getHistory(t.id)).length, 1);
      }

      // Повторный импорт тех же задач ничего не добавляет.
      final f = bad(await env.importTodos(
          projectId: s.project, actorId: s.user, todos: todos));
      expect(f.message, contains('уже есть'));
      expect(
          ok(await env.taskRepo.watchTasks(const TaskFilterEntity()).first)
              .length,
          2);
    });

    test('21. Пустой импорт не выполняется', () async {
      final s = await env.basic();
      expect(
          bad(await env.importTodos(
              projectId: s.project, actorId: s.user, todos: const [])),
          isA<ValidationFailure>());
    });
  });
}
