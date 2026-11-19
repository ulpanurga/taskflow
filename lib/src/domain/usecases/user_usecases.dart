import 'package:dartz/dartz.dart';
import 'package:taskflow/constants/app_constants.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/repositories/user_repository.dart';

/// Проверка имени и email. Возвращает текст ошибки или null.
String? validateUserFields(String name, String email) {
  if (name.trim().isEmpty) return 'Имя не может быть пустым';
  if (!kEmailRegExp.hasMatch(email.trim())) return 'Некорректный email';
  return null;
}

const _emailTaken = ValidationFailure('Пользователь с таким email уже есть');

class WatchUsers {
  final UserRepository _repo;
  const WatchUsers(this._repo);

  Stream<Either<Failure, List<UserEntity>>> call() => _repo.watchUsers();
}

class GetUsers {
  final UserRepository _repo;
  const GetUsers(this._repo);

  Future<Either<Failure, List<UserEntity>>> call() => _repo.getUsers();
}

class CreateUser {
  final UserRepository _repo;
  const CreateUser(this._repo);

  Future<Either<Failure, int>> call(
      {required String name, required String email}) async {
    final error = validateUserFields(name, email);
    if (error != null) return Left(ValidationFailure(error));

    final exists = await _repo.emailExists(email);
    return exists.thenAsync<int>((taken) async {
      if (taken) return const Left(_emailTaken);
      return _repo.createUser(
        name: name.trim(),
        email: email.trim().toLowerCase(),
      );
    });
  }
}

class UpdateUser {
  final UserRepository _repo;
  const UpdateUser(this._repo);

  Future<Either<Failure, Unit>> call(
      {required int id, required String name, required String email}) async {
    final error = validateUserFields(name, email);
    if (error != null) return Left(ValidationFailure(error));

    final exists = await _repo.emailExists(email, exceptId: id);
    return exists.thenAsync<Unit>((taken) async {
      if (taken) return const Left(_emailTaken);
      return _repo.updateUser(
        id: id,
        name: name.trim(),
        email: email.trim().toLowerCase(),
      );
    });
  }
}

/// Нельзя удалить пользователя, у которого есть незавершённые задачи.
class DeleteUser {
  final UserRepository _repo;
  const DeleteUser(this._repo);

  Future<Either<Failure, Unit>> call(int id) async {
    final open = await _repo.countOpenTasksOfUser(id);
    return open.thenAsync<Unit>((count) async {
      if (count > 0) {
        return Left(ValidationFailure(
            'Нельзя удалить: у пользователя $count незавершённых задач'));
      }
      return _repo.deleteUser(id);
    });
  }
}
