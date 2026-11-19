import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';

abstract class UserRepository {
  Stream<Either<Failure, List<UserEntity>>> watchUsers();
  Future<Either<Failure, List<UserEntity>>> getUsers();
  Future<Either<Failure, int>> createUser(
      {required String name, required String email});
  Future<Either<Failure, Unit>> updateUser(
      {required int id, required String name, required String email});
  Future<Either<Failure, Unit>> deleteUser(int id);
  Future<Either<Failure, bool>> emailExists(String email, {int? exceptId});
  Future<Either<Failure, int>> countOpenTasksOfUser(int userId);
}
