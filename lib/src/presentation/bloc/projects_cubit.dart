import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

class ProjectsCubit extends WatchCubit<List<ProjectEntity>> {
  final WatchProjects _watch;
  final CreateProject _create;
  final UpdateProject _update;
  final DeleteProject _delete;

  ProjectsCubit(this._watch, this._create, this._update, this._delete);

  @override
  Stream<Either<Failure, List<ProjectEntity>>> watchSource() => _watch();

  Future<Failure?> create({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? finishedAt,
  }) async =>
      (await _create(
        name: name,
        description: description,
        status: status,
        finishedAt: finishedAt,
      ))
          .failureOrNull;

  Future<Failure?> update(
    int id, {
    required String name,
    String description = '',
    required ProjectStatus status,
    DateTime? finishedAt,
  }) async =>
      (await _update(
        id: id,
        name: name,
        description: description,
        status: status,
        finishedAt: finishedAt,
      ))
          .failureOrNull;

  Future<Failure?> delete(int id) async => (await _delete(id)).failureOrNull;
}
