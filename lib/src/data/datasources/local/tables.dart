import 'package:drift/drift.dart';

import 'package:taskflow/src/domain/entities/enums.dart';

/// 1. Пользователи
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().withLength(min: 3, max: 200).unique()();
  DateTimeColumn get registeredAt => dateTime().withDefault(currentDateAndTime)();
}

/// 2. Проекты
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get status => textEnum<ProjectStatus>()
      .withDefault(Constant(ProjectStatus.active.name))();
}

/// 3. Участники проектов (связь многие-ко-многим users <-> projects)
class ProjectMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().customConstraint(
          'NOT NULL REFERENCES projects(id) ON DELETE CASCADE')();
  IntColumn get userId =>
      integer().customConstraint(
          'NOT NULL REFERENCES users(id) ON DELETE CASCADE')();
  TextColumn get role =>
      textEnum<MemberRole>().withDefault(Constant(MemberRole.member.name))();

  /// Один пользователь не может быть добавлен в проект дважды.
  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, userId},
      ];
}

/// 4. Задачи (One-to-Many: проект -> задачи, пользователь -> задачи)
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get projectId =>
      integer().customConstraint(
          'NOT NULL REFERENCES projects(id) ON DELETE CASCADE')();
  IntColumn get assigneeId =>
      integer().nullable().customConstraint(
          'REFERENCES users(id) ON DELETE SET NULL')();
  // Поле priority добавлено во второй версии схемы (см. миграцию).
  TextColumn get priority => textEnum<TaskPriority>()
      .withDefault(Constant(TaskPriority.medium.name))();
  TextColumn get status =>
      textEnum<TaskStatus>().withDefault(Constant(TaskStatus.todo.name))();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // Soft Delete: если не null — задача в корзине.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// 5. Комментарии
class Comments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text().withLength(min: 1, max: 2000)();
  IntColumn get authorId =>
      integer().customConstraint(
          'NOT NULL REFERENCES users(id) ON DELETE CASCADE')();
  IntColumn get taskId =>
      integer().customConstraint(
          'NOT NULL REFERENCES tasks(id) ON DELETE CASCADE')();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 6. Вложения (хранится только путь к файлу)
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text().withLength(min: 1, max: 255)();
  TextColumn get filePath => text()();
  IntColumn get taskId =>
      integer().customConstraint(
          'NOT NULL REFERENCES tasks(id) ON DELETE CASCADE')();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 7. История изменений задач
@DataClassName('HistoryEntry')
class TaskHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().customConstraint(
          'NOT NULL REFERENCES tasks(id) ON DELETE CASCADE')();
  TextColumn get action => textEnum<HistoryAction>()
      .withDefault(Constant(HistoryAction.statusChanged.name))();
  // Для первой записи (создание задачи) предыдущего статуса нет.
  TextColumn get oldStatus => textEnum<TaskStatus>().nullable()();
  TextColumn get newStatus => textEnum<TaskStatus>()();
  IntColumn get changedBy =>
      integer().nullable().customConstraint(
          'REFERENCES users(id) ON DELETE SET NULL')();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  // true, если это изменение уже отменено через Undo
  BoolColumn get isUndone => boolean().withDefault(const Constant(false))();
}
