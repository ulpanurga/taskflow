import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';

abstract class ProjectRepository {
  Stream<Either<Failure, List<ProjectEntity>>> watchProjects();
  Future<Either<Failure, List<ProjectEntity>>> getProjects();
  Future<Either<Failure, int>> createProject({
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  });
  Future<Either<Failure, Unit>> updateProject({
    required int id,
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  });
  Future<Either<Failure, Unit>> deleteProject(int id);

  // Участники
  Stream<Either<Failure, List<MemberEntity>>> watchMembers(int projectId);
  Future<Either<Failure, List<UserEntity>>> getMemberUsers(int projectId);
  Future<Either<Failure, Unit>> addMember(
      {required int projectId, required int userId, required MemberRole role});
  Future<Either<Failure, Unit>> removeMember(
      {required int projectId, required int userId});
  Future<Either<Failure, Unit>> setMemberRole(
      {required int projectId, required int userId, required MemberRole role});
  Future<Either<Failure, bool>> isMember(int projectId, int userId);
  Future<Either<Failure, int>> countOpenTasksOfMember(
      int projectId, int userId);
}
