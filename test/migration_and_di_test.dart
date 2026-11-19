import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:taskflow/core/di/injection.dart';
import 'package:taskflow/src/data/datasources/local/app_database.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/task_repository.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/presentation/bloc/attachments_cubit.dart';
import 'package:taskflow/src/presentation/bloc/comments_cubit.dart';
import 'package:taskflow/src/presentation/bloc/dashboard_cubit.dart';
import 'package:taskflow/src/presentation/bloc/import_cubit.dart';
import 'package:taskflow/src/presentation/bloc/project_members_cubit.dart';
import 'package:taskflow/src/presentation/bloc/projects_cubit.dart';
import 'package:taskflow/src/presentation/bloc/task_detail_cubit.dart';
import 'package:taskflow/src/presentation/bloc/task_form_cubit.dart';
import 'package:taskflow/src/presentation/bloc/task_history_cubit.dart';
import 'package:taskflow/src/presentation/bloc/tasks_cubit.dart';
import 'package:taskflow/src/presentation/bloc/trash_cubit.dart';
import 'package:taskflow/src/presentation/bloc/users_cubit.dart';

void main() {
  test('36. Миграция v1 -> v2: появляется priority, старые данные целы',
      () async {
    final dir = Directory.systemTemp.createTempSync('taskflow_mig');
    final file = File('${dir.path}/old.sqlite');

    // База первой версии: таблица tasks без поля priority.
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

    final migrated = AppDatabase(NativeDatabase(file));
    final rows = await migrated
        .customSelect('SELECT title, priority, status FROM tasks ORDER BY id')
        .get();

    expect(rows.length, 2);
    expect(rows[0].read<String>('title'), 'Старая 1');
    expect(rows[0].read<String>('priority'), 'medium');
    expect(rows[1].read<String>('priority'), 'medium');
    expect(rows[1].read<String>('status'), 'done');

    await migrated.close();
    dir.deleteSync(recursive: true);
  });

  test('37. DI: все зависимости регистрируются и создаются', () async {
    await configureDependencies(database: AppDatabase.memory());

    // Repository регистрируется по абстракции из Domain.
    expect(getIt<TaskRepository>(), isA<TaskRepository>());
    expect(getIt<CreateTask>(), isA<CreateTask>());

    final cubits = <BlocBase<Object?>>[
      getIt<UsersCubit>(),
      getIt<ProjectsCubit>(),
      getIt<DashboardCubit>(),
      getIt<TrashCubit>(),
      getIt<TaskFormCubit>(),
      getIt<TasksCubit>(param1: const TaskFilterEntity()),
      getIt<ProjectMembersCubit>(param1: 1),
      getIt<TaskDetailCubit>(param1: 1),
      getIt<TaskHistoryCubit>(param1: 1),
      getIt<CommentsCubit>(param1: 1),
      getIt<AttachmentsCubit>(param1: 1),
      getIt<ImportCubit>(param1: 1),
    ];
    expect(cubits.length, 12);
    for (final c in cubits) {
      await c.close();
    }

    await getIt<AppDatabase>().close();
    await getIt.reset();
  });
}
