import 'package:get_it/get_it.dart';
import 'package:taskflow/core/rest_client/api_client.dart';
import 'package:taskflow/src/data/datasources/local/app_database.dart';
import 'package:taskflow/src/data/datasources/local/other_local_datasources.dart';
import 'package:taskflow/src/data/datasources/local/project_local_datasource.dart';
import 'package:taskflow/src/data/datasources/local/task_local_datasource.dart';
import 'package:taskflow/src/data/datasources/local/user_local_datasource.dart';
import 'package:taskflow/src/data/datasources/remote/task_remote_datasource.dart';
import 'package:taskflow/src/data/repositories/other_repositories_impl.dart';
import 'package:taskflow/src/data/repositories/project_repository_impl.dart';
import 'package:taskflow/src/data/repositories/task_repository_impl.dart';
import 'package:taskflow/src/data/repositories/user_repository_impl.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/other_repositories.dart';
import 'package:taskflow/src/domain/repositories/project_repository.dart';
import 'package:taskflow/src/domain/repositories/task_repository.dart';
import 'package:taskflow/src/domain/repositories/user_repository.dart';
import 'package:taskflow/src/domain/usecases/comment_attachment_usecases.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';
import 'package:taskflow/src/domain/usecases/stats_import_usecases.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/domain/usecases/user_usecases.dart';
import 'package:taskflow/src/presentation/bloc/attachments_cubit.dart';
import 'package:taskflow/src/presentation/bloc/comments_cubit.dart';
import 'package:taskflow/src/presentation/bloc/dashboard_cubit.dart';
import 'package:taskflow/src/presentation/bloc/import_cubit.dart';
import 'package:taskflow/src/presentation/bloc/project_members_cubit.dart';
import 'package:taskflow/src/presentation/bloc/projects_cubit.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';
import 'package:taskflow/src/presentation/bloc/task_detail_cubit.dart';
import 'package:taskflow/src/presentation/bloc/task_form_cubit.dart';
import 'package:taskflow/src/presentation/bloc/task_history_cubit.dart';
import 'package:taskflow/src/presentation/bloc/tasks_cubit.dart';
import 'package:taskflow/src/presentation/bloc/trash_cubit.dart';
import 'package:taskflow/src/presentation/bloc/users_cubit.dart';

final getIt = GetIt.instance;

/// Все зависимости регистрируются здесь, в правильном порядке:
/// 1) база и HTTP-клиент  2) DataSource-ы  3) Repository
/// 4) UseCase-ы  5) Cubit-ы.
/// Каждый следующий слой получает уже зарегистрированный предыдущий.
Future<void> configureDependencies({AppDatabase? database}) async {
  await getIt.reset();

  // ---------- 1. Внешние зависимости ----------
  getIt.registerSingleton<AppDatabase>(database ?? AppDatabase(openConnection()));
  getIt.registerLazySingleton<ApiClient>(() => ApiClient.create());

  // ---------- 2. DataSource ----------
  getIt.registerLazySingleton<UserLocalDataSource>(
      () => UserLocalDataSource(getIt()));
  getIt.registerLazySingleton<ProjectLocalDataSource>(
      () => ProjectLocalDataSource(getIt()));
  getIt.registerLazySingleton<TaskLocalDataSource>(
      () => TaskLocalDataSource(getIt()));
  getIt.registerLazySingleton<CommentLocalDataSource>(
      () => CommentLocalDataSource(getIt()));
  getIt.registerLazySingleton<AttachmentLocalDataSource>(
      () => AttachmentLocalDataSource(getIt()));
  getIt.registerLazySingleton<StatsLocalDataSource>(
      () => StatsLocalDataSource(getIt()));
  getIt.registerLazySingleton<TaskRemoteDataSource>(
      () => TaskRemoteDataSourceImpl(getIt()));

  // ---------- 3. Repository (регистрируем по абстракции из Domain) ----------
  getIt.registerLazySingleton<UserRepository>(() => UserRepositoryImpl(getIt()));
  getIt.registerLazySingleton<ProjectRepository>(
      () => ProjectRepositoryImpl(getIt()));
  getIt.registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(getIt()));
  getIt.registerLazySingleton<CommentRepository>(
      () => CommentRepositoryImpl(getIt()));
  getIt.registerLazySingleton<AttachmentRepository>(
      () => AttachmentRepositoryImpl(getIt()));
  getIt.registerLazySingleton<StatsRepository>(
      () => StatsRepositoryImpl(getIt()));
  getIt.registerLazySingleton<RemoteTodoRepository>(
      () => RemoteTodoRepositoryImpl(getIt()));

  // ---------- 4. UseCase ----------
  // Пользователи
  getIt.registerFactory(() => WatchUsers(getIt()));
  getIt.registerFactory(() => GetUsers(getIt()));
  getIt.registerFactory(() => CreateUser(getIt()));
  getIt.registerFactory(() => UpdateUser(getIt()));
  getIt.registerFactory(() => DeleteUser(getIt()));
  // Проекты и участники
  getIt.registerFactory(() => WatchProjects(getIt()));
  getIt.registerFactory(() => GetProjects(getIt()));
  getIt.registerFactory(() => CreateProject(getIt()));
  getIt.registerFactory(() => UpdateProject(getIt()));
  getIt.registerFactory(() => DeleteProject(getIt()));
  getIt.registerFactory(() => WatchMembers(getIt()));
  getIt.registerFactory(() => GetMemberUsers(getIt()));
  getIt.registerFactory(() => AddMember(getIt()));
  getIt.registerFactory(() => RemoveMember(getIt()));
  getIt.registerFactory(() => SetMemberRole(getIt()));
  // Задачи
  getIt.registerFactory(() => WatchTasks(getIt()));
  getIt.registerFactory(() => WatchTask(getIt()));
  getIt.registerFactory(() => WatchTaskHistory(getIt()));
  getIt.registerFactory(() => CreateTask(getIt(), getIt()));
  getIt.registerFactory(() => UpdateTask(getIt()));
  getIt.registerFactory(() => ChangeTaskPriority(getIt()));
  getIt.registerFactory(() => ChangeTaskStatus(getIt()));
  getIt.registerFactory(() => ReassignTask(getIt(), getIt()));
  getIt.registerFactory(() => UndoStatusChange(getIt()));
  getIt.registerFactory(() => MoveTaskToTrash(getIt()));
  getIt.registerFactory(() => RestoreTask(getIt()));
  getIt.registerFactory(() => DeleteTaskPermanently(getIt()));
  // Комментарии и вложения
  getIt.registerFactory(() => WatchComments(getIt()));
  getIt.registerFactory(() => AddComment(getIt(), getIt()));
  getIt.registerFactory(() => DeleteComment(getIt()));
  getIt.registerFactory(() => WatchAttachments(getIt()));
  getIt.registerFactory(() => AddAttachment(getIt(), getIt()));
  getIt.registerFactory(() => DeleteAttachment(getIt()));
  // Статистика и импорт
  getIt.registerFactory(() => WatchDashboardStats(getIt()));
  getIt.registerFactory(() => FetchRemoteTodos(getIt()));
  getIt.registerFactory(() => ImportTodos(getIt()));

  // ---------- 5. Cubit ----------
  // Текущий пользователь — один на всё приложение.
  getIt.registerLazySingleton<SessionCubit>(() => SessionCubit());

  getIt.registerFactory(() => UsersCubit(
      getIt(), getIt(), getIt(), getIt(), getIt(), getIt<SessionCubit>()));
  getIt.registerFactory(
      () => ProjectsCubit(getIt(), getIt(), getIt(), getIt()));
  getIt.registerFactory(() => DashboardCubit(getIt()));
  getIt.registerFactory(() => TrashCubit(getIt(), getIt(), getIt(), getIt<SessionCubit>()));
  getIt.registerFactory(() => TaskFormCubit(
      getIt(), getIt(), getIt(), getIt(), getIt(), getIt<SessionCubit>()));

  // Cubit-ы с параметром (id проекта / задачи, фильтр)
  getIt.registerFactoryParam<TasksCubit, TaskFilterEntity, void>(
      (filter, _) => TasksCubit(getIt(), filter));
  getIt.registerFactoryParam<ProjectMembersCubit, int, void>(
      (projectId, _) => ProjectMembersCubit(
          projectId, getIt(), getIt(), getIt(), getIt(), getIt(), getIt()));
  getIt.registerFactoryParam<TaskDetailCubit, int, void>(
      (taskId, _) => TaskDetailCubit(taskId, getIt(), getIt(), getIt(),
          getIt(), getIt(), getIt(), getIt(), getIt<SessionCubit>()));
  getIt.registerFactoryParam<TaskHistoryCubit, int, void>(
      (taskId, _) => TaskHistoryCubit(taskId, getIt()));
  getIt.registerFactoryParam<CommentsCubit, int, void>(
      (taskId, _) => CommentsCubit(
          taskId, getIt(), getIt(), getIt(), getIt<SessionCubit>()));
  getIt.registerFactoryParam<AttachmentsCubit, int, void>(
      (taskId, _) => AttachmentsCubit(taskId, getIt(), getIt(), getIt()));
  getIt.registerFactoryParam<ImportCubit, int, void>((projectId, _) =>
      ImportCubit(projectId, getIt(), getIt(), getIt<SessionCubit>()));
}
