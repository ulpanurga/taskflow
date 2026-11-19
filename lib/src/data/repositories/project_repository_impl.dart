import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/data/datasources/local/project_local_datasource.dart';
import 'package:taskflow/src/data/mapper/mappers.dart';
import 'package:taskflow/src/data/repositories/local_repository.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl extends LocalRepository
    implements ProjectRepository {
  final ProjectLocalDataSource _local;
  const ProjectRepositoryImpl(this._local);

  @override
  Stream<Either<Failure, List<ProjectEntity>>> watchProjects() => watch(_local
      .watchAll()
      .map((rows) => rows.map((p) => p.toEntity()).toList()));

  @override
  Future<Either<Failure, List<ProjectEntity>>> getProjects() => run(() async {
        final rows = await _local.getAll();
        return rows.map((p) => p.toEntity()).toList();
      });

  @override
  Future<Either<Failure, int>> createProject({
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) =>
      run(() => _local.insert(
            name: name,
            description: description,
            status: status,
            finishedAt: finishedAt,
          ));

  @override
  Future<Either<Failure, Unit>> updateProject({
    required int id,
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) =>
      run(() async {
        await _local.update(
          id: id,
          name: name,
          description: description,
          status: status,
          finishedAt: finishedAt,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> deleteProject(int id) => run(() async {
        await _local.delete(id);
        return unit;
      });

  @override
  Stream<Either<Failure, List<MemberEntity>>> watchMembers(int projectId) =>
      watch(_local
          .watchMembers(projectId)
          .map((rows) => rows.map((r) => r.toEntity()).toList()));

  @override
  Future<Either<Failure, List<UserEntity>>> getMemberUsers(int projectId) =>
      run(() async {
        final rows = await _local.getMemberUsers(projectId);
        return rows.map((u) => u.toEntity()).toList();
      });

  @override
  Future<Either<Failure, Unit>> addMember(
          {required int projectId,
          required int userId,
          required MemberRole role}) =>
      run(() async {
        await _local.addMember(projectId, userId, role);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> removeMember(
          {required int projectId, required int userId}) =>
      run(() async {
        await _local.removeMember(projectId, userId);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> setMemberRole(
          {required int projectId,
          required int userId,
          required MemberRole role}) =>
      run(() async {
        await _local.setRole(projectId, userId, role);
        return unit;
      });

  @override
  Future<Either<Failure, bool>> isMember(int projectId, int userId) =>
      run(() => _local.isMember(projectId, userId));

  @override
  Future<Either<Failure, int>> countOpenTasksOfMember(
          int projectId, int userId) =>
      run(() => _local.countOpenTasksOfMember(projectId, userId));
}
