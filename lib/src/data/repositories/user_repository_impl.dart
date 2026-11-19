import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/data/datasources/local/user_local_datasource.dart';
import 'package:taskflow/src/data/mapper/mappers.dart';
import 'package:taskflow/src/data/repositories/local_repository.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/repositories/user_repository.dart';

class UserRepositoryImpl extends LocalRepository implements UserRepository {
  final UserLocalDataSource _local;
  const UserRepositoryImpl(this._local);

  @override
  Stream<Either<Failure, List<UserEntity>>> watchUsers() => watch(
      _local.watchAll().map((rows) => rows.map((u) => u.toEntity()).toList()));

  @override
  Future<Either<Failure, List<UserEntity>>> getUsers() => run(() async {
        final rows = await _local.getAll();
        return rows.map((u) => u.toEntity()).toList();
      });

  @override
  Future<Either<Failure, int>> createUser(
          {required String name, required String email}) =>
      run(() => _local.insert(name, email));

  @override
  Future<Either<Failure, Unit>> updateUser(
          {required int id, required String name, required String email}) =>
      run(() async {
        await _local.update(id, name, email);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> deleteUser(int id) => run(() async {
        await _local.delete(id);
        return unit;
      });

  @override
  Future<Either<Failure, bool>> emailExists(String email, {int? exceptId}) =>
      run(() => _local.emailExists(email, exceptId: exceptId));

  @override
  Future<Either<Failure, int>> countOpenTasksOfUser(int userId) =>
      run(() => _local.countOpenTasks(userId));
}
