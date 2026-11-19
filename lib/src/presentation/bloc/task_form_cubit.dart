import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';

class TaskFormState extends Equatable {
  final bool loading;
  final Failure? failure;
  final List<ProjectEntity> projects;
  final List<UserEntity> members;

  const TaskFormState({
    this.loading = true,
    this.failure,
    this.projects = const [],
    this.members = const [],
  });

  @override
  List<Object?> get props => [loading, failure, projects, members];
}

/// Форма создания и редактирования задачи.
class TaskFormCubit extends Cubit<TaskFormState> {
  final GetProjects _getProjects;
  final GetMemberUsers _getMembers;
  final CreateTask _create;
  final UpdateTask _update;
  final ReassignTask _reassign;
  final SessionCubit _session;

  TaskFormCubit(this._getProjects, this._getMembers, this._create,
      this._update, this._reassign, this._session)
      : super(const TaskFormState());

  /// Загружает проекты и участников выбранного проекта.
  Future<void> init({int? projectId}) async {
    emit(const TaskFormState());
    final projects = await _getProjects();
    final failure = projects.failureOrNull;
    if (failure != null) {
      emit(TaskFormState(loading: false, failure: failure));
      return;
    }
    final list = projects.getOrElse(() => const []);
    final members = projectId == null
        ? <UserEntity>[]
        : (await _getMembers(projectId)).getOrElse(() => const []);
    emit(TaskFormState(loading: false, projects: list, members: members));
  }

  /// Пользователь выбрал другой проект: список исполнителей меняется.
  Future<void> selectProject(int? projectId) async {
    final members = projectId == null
        ? <UserEntity>[]
        : (await _getMembers(projectId)).getOrElse(() => const []);
    emit(TaskFormState(
        loading: false, projects: state.projects, members: members));
  }

  Future<Failure?> save({
    TaskEntity? existing,
    required int? projectId,
    required String title,
    required String description,
    required int? assigneeId,
    required TaskPriority priority,
    required DateTime? deadline,
  }) async {
    final actor = _session.state;
    if (actor == null) return SessionCubit.noUserFailure;

    if (existing == null) {
      return (await _create(
        projectId: projectId,
        title: title,
        description: description,
        assigneeId: assigneeId,
        priority: priority,
        deadline: deadline,
        actorId: actor,
      ))
          .failureOrNull;
    }

    final updated = await _update(
      taskId: existing.id,
      title: title,
      description: description,
      priority: priority,
      deadline: deadline,
    );
    final failure = updated.failureOrNull;
    if (failure != null) return failure;

    if (assigneeId != existing.assigneeId) {
      return (await _reassign(
              taskId: existing.id, newAssigneeId: assigneeId, actorId: actor))
          .failureOrNull;
    }
    return null;
  }
}
