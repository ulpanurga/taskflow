import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/usecases/user_usecases.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

/// Действия возвращают Failure (или null, если всё хорошо),
/// экран сам решает, как показать ошибку.
class UsersCubit extends WatchCubit<List<UserEntity>> {
  final WatchUsers _watch;
  final GetUsers _getUsers;
  final CreateUser _create;
  final UpdateUser _update;
  final DeleteUser _delete;
  final SessionCubit _session;

  UsersCubit(this._watch, this._getUsers, this._create, this._update,
      this._delete, this._session);

  @override
  Stream<Either<Failure, List<UserEntity>>> watchSource() => _watch();

  Future<List<UserEntity>> loadAll() async =>
      (await _getUsers()).getOrElse(() => const []);

  Future<Failure?> create(String name, String email) async {
    final result = await _create(name: name, email: email);
    return result.fold<Failure?>((f) => f, (id) {
      // Первый созданный пользователь становится текущим.
      if (_session.state == null) _session.setUser(id);
      return null;
    });
  }

  Future<Failure?> update(int id, String name, String email) async =>
      (await _update(id: id, name: name, email: email)).failureOrNull;

  Future<Failure?> delete(int id) async {
    final result = await _delete(id);
    return result.fold<Failure?>((f) => f, (_) {
      if (_session.state == id) _session.setUser(null);
      return null;
    });
  }

  void makeCurrent(int id) => _session.setUser(id);
}
