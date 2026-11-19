import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/dashboard_stats_entity.dart';
import 'package:taskflow/src/domain/usecases/stats_import_usecases.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

class DashboardCubit extends WatchCubit<DashboardStatsEntity> {
  final WatchDashboardStats _watch;
  DashboardCubit(this._watch);

  @override
  Stream<Either<Failure, DashboardStatsEntity>> watchSource() => _watch();
}
