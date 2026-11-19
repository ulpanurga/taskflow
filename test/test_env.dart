import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/data/datasources/local/app_database.dart';
import 'package:taskflow/src/data/datasources/local/other_local_datasources.dart';
import 'package:taskflow/src/data/datasources/local/project_local_datasource.dart';
import 'package:taskflow/src/data/datasources/local/task_local_datasource.dart';
import 'package:taskflow/src/data/datasources/local/user_local_datasource.dart';
import 'package:taskflow/src/data/repositories/other_repositories_impl.dart';
import 'package:taskflow/src/data/repositories/project_repository_impl.dart';
import 'package:taskflow/src/data/repositories/task_repository_impl.dart';
import 'package:taskflow/src/data/repositories/user_repository_impl.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/usecases/comment_attachment_usecases.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';
import 'package:taskflow/src/domain/usecases/stats_import_usecases.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/domain/usecases/user_usecases.dart';

/// Настоящие репозитории и UseCase-ы поверх базы в памяти.
/// Так тесты проверяют всю цепочку Domain -> Data -> SQLite.
class TestEnv {
  final AppDatabase db = AppDatabase.memory();

  late final userRepo = UserRepositoryImpl(UserLocalDataSource(db));
  late final projectRepo = ProjectRepositoryImpl(ProjectLocalDataSource(db));
  late final taskRepo = TaskRepositoryImpl(TaskLocalDataSource(db));
  late final commentRepo = CommentRepositoryImpl(CommentLocalDataSource(db));
  late final statsRepo = StatsRepositoryImpl(StatsLocalDataSource(db));

  late final createUser = CreateUser(userRepo);
  late final deleteUser = DeleteUser(userRepo);
  late final createProject = CreateProject(projectRepo);
  late final deleteProject = DeleteProject(projectRepo);
  late final addMember = AddMember(projectRepo);
  late final removeMember = RemoveMember(projectRepo);
  late final createTask = CreateTask(taskRepo, projectRepo);
  late final updateTask = UpdateTask(taskRepo);
  late final changeStatus = ChangeTaskStatus(taskRepo);
  late final reassign = ReassignTask(taskRepo, projectRepo);
  late final undo = UndoStatusChange(taskRepo);
  late final trash = MoveTaskToTrash(taskRepo);
  late final restore = RestoreTask(taskRepo);
  late final deleteForever = DeleteTaskPermanently(taskRepo);
  late final addComment = AddComment(commentRepo, taskRepo);
  late final deleteComment = DeleteComment(commentRepo);
  late final importTodos = ImportTodos(taskRepo);

  Future<void> close() => db.close();

  /// Проект + пользователь, который в нём состоит.
  Future<({int project, int user})> basic() async {
    final u = ok(await createUser(name: 'Анна', email: 'anna@mail.com'));
    final p = ok(await createProject(name: 'Проект А'));
    ok(await addMember(projectId: p, userId: u, role: MemberRole.owner));
    return (project: p, user: u);
  }
}

/// Достаёт значение из Right или роняет тест.
T ok<T>(Either<Failure, T> result) => result.fold(
      (f) => throw TestFailure('Ожидали успех, а пришла ошибка: ${f.message}'),
      (value) => value,
    );

/// Достаёт Failure из Left или роняет тест.
Failure bad<T>(Either<Failure, T> result) => result.fold(
      (f) => f,
      (value) => throw TestFailure('Ожидали ошибку, а пришло: $value'),
    );
