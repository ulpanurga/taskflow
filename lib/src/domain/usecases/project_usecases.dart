import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/repositories/project_repository.dart';

const _emptyProjectName =
    ValidationFailure('Название проекта не может быть пустым');

class WatchProjects {
  final ProjectRepository _repo;
  const WatchProjects(this._repo);

  Stream<Either<Failure, List<ProjectEntity>>> call() =>
      _repo.watchProjects();
}

class GetProjects {
  final ProjectRepository _repo;
  const GetProjects(this._repo);

  Future<Either<Failure, List<ProjectEntity>>> call() => _repo.getProjects();
}

class CreateProject {
  final ProjectRepository _repo;
  const CreateProject(this._repo);

  Future<Either<Failure, int>> call({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? finishedAt,
  }) async {
    if (name.trim().isEmpty) return const Left(_emptyProjectName);
    return _repo.createProject(
      name: name.trim(),
      description: description,
      status: status,
      finishedAt: finishedAt,
    );
  }
}

class UpdateProject {
  final ProjectRepository _repo;
  const UpdateProject(this._repo);

  Future<Either<Failure, Unit>> call({
    required int id,
    required String name,
    String description = '',
    required ProjectStatus status,
    DateTime? finishedAt,
  }) async {
    if (name.trim().isEmpty) return const Left(_emptyProjectName);
    return _repo.updateProject(
      id: id,
      name: name.trim(),
      description: description,
      status: status,
      finishedAt: finishedAt,
    );
  }
}

/// Задачи, комментарии и история удаляются вместе с проектом (CASCADE).
class DeleteProject {
  final ProjectRepository _repo;
  const DeleteProject(this._repo);

  Future<Either<Failure, Unit>> call(int id) => _repo.deleteProject(id);
}

class WatchMembers {
  final ProjectRepository _repo;
  const WatchMembers(this._repo);

  Stream<Either<Failure, List<MemberEntity>>> call(int projectId) =>
      _repo.watchMembers(projectId);
}

/// Пользователи, которые состоят в проекте.
class GetMemberUsers {
  final ProjectRepository _repo;
  const GetMemberUsers(this._repo);

  Future<Either<Failure, List<UserEntity>>> call(int projectId) =>
      _repo.getMemberUsers(projectId);
}

class AddMember {
  final ProjectRepository _repo;
  const AddMember(this._repo);

  Future<Either<Failure, Unit>> call({
    required int projectId,
    required int userId,
    MemberRole role = MemberRole.member,
  }) async {
    final already = await _repo.isMember(projectId, userId);
    return already.thenAsync<Unit>((isMember) async {
      if (isMember) {
        return const Left(
            ValidationFailure('Пользователь уже состоит в проекте'));
      }
      return _repo.addMember(
          projectId: projectId, userId: userId, role: role);
    });
  }
}

/// Нельзя убрать участника, пока у него есть незавершённые задачи проекта.
class RemoveMember {
  final ProjectRepository _repo;
  const RemoveMember(this._repo);

  Future<Either<Failure, Unit>> call(
      {required int projectId, required int userId}) async {
    final open = await _repo.countOpenTasksOfMember(projectId, userId);
    return open.thenAsync<Unit>((count) async {
      if (count > 0) {
        return Left(ValidationFailure(
            'У участника $count незавершённых задач в проекте. '
            'Сначала переназначьте их.'));
      }
      return _repo.removeMember(projectId: projectId, userId: userId);
    });
  }
}

class SetMemberRole {
  final ProjectRepository _repo;
  const SetMemberRole(this._repo);

  Future<Either<Failure, Unit>> call(
          {required int projectId,
          required int userId,
          required MemberRole role}) =>
      _repo.setMemberRole(projectId: projectId, userId: userId, role: role);
}
