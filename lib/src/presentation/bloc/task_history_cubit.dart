import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

class TaskHistoryCubit extends WatchCubit<List<HistoryEntryEntity>> {
  final int taskId;
  final WatchTaskHistory _watch;
  TaskHistoryCubit(this.taskId, this._watch);

  @override
  Stream<Either<Failure, List<HistoryEntryEntity>>> watchSource() =>
      _watch(taskId);
}
