import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';
import 'package:taskflow/src/domain/usecases/user_usecases.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

class ProjectMembersCubit extends WatchCubit<List<MemberEntity>> {
  final int projectId;
  final WatchMembers _watch;
  final GetUsers _getUsers;
  final GetMemberUsers _getMemberUsers;
  final AddMember _add;
  final RemoveMember _remove;
  final SetMemberRole _setRole;

  ProjectMembersCubit(this.projectId, this._watch, this._getUsers,
      this._getMemberUsers, this._add, this._remove, this._setRole);

  @override
  Stream<Either<Failure, List<MemberEntity>>> watchSource() =>
      _watch(projectId);

  /// Пользователи, которых ещё нет в проекте.
  Future<List<UserEntity>> candidates() async {
    final all = (await _getUsers()).getOrElse(() => const []);
    final members = (await _getMemberUsers(projectId)).getOrElse(() => const []);
    final memberIds = members.map((u) => u.id).toSet();
    return all.where((u) => !memberIds.contains(u.id)).toList();
  }

  Future<Failure?> add(int userId, MemberRole role) async =>
      (await _add(projectId: projectId, userId: userId, role: role))
          .failureOrNull;

  Future<Failure?> remove(int userId) async =>
      (await _remove(projectId: projectId, userId: userId)).failureOrNull;

  Future<Failure?> setRole(int userId, MemberRole role) async =>
      (await _setRole(projectId: projectId, userId: userId, role: role))
          .failureOrNull;
}
