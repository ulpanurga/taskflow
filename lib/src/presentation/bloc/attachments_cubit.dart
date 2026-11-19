import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/usecases/comment_attachment_usecases.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

class AttachmentsCubit extends WatchCubit<List<AttachmentEntity>> {
  final int taskId;
  final WatchAttachments _watch;
  final AddAttachment _add;
  final DeleteAttachment _delete;

  AttachmentsCubit(this.taskId, this._watch, this._add, this._delete);

  @override
  Stream<Either<Failure, List<AttachmentEntity>>> watchSource() =>
      _watch(taskId);

  Future<Failure?> add(String fileName, String filePath) async =>
      (await _add(taskId: taskId, fileName: fileName, filePath: filePath))
          .failureOrNull;

  Future<Failure?> delete(int id) async => (await _delete(id)).failureOrNull;
}
