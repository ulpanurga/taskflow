import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:taskflow/src/domain/entities/enums.dart';

import 'indexes.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users,
  Projects,
  ProjectMembers,
  Tasks,
  Comments,
  Attachments,
  TaskHistory,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  /// База в оперативной памяти — для тестов.
  AppDatabase.memory() : super(NativeDatabase.memory());

  /// Версия 1: таблица tasks без поля priority.
  /// Версия 2: добавлено поле priority (по умолчанию 'medium').
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final sql in kIndexes.values) {
            await customStatement(sql);
          }
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // ALTER TABLE tasks ADD COLUMN priority TEXT NOT NULL DEFAULT 'medium'
            // Все старые записи автоматически получают значение 'medium'.
            await m.addColumn(tasks, tasks.priority);
          }
        },
        beforeOpen: (details) async {
          // Без этой команды SQLite не проверяет внешние ключи.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Открывает файл базы данных на устройстве.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'taskflow.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
