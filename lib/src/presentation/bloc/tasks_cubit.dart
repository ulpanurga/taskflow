import 'package:dartz/dartz.dart';
import 'package:taskflow/constants/app_constants.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

/// Список задач: фильтры, сортировка, поиск и пагинация.
/// Один и тот же Cubit используется для всех задач, задач проекта
/// и задач пользователя — отличается только начальный фильтр.
class TasksCubit extends WatchCubit<List<TaskEntity>> {
  final WatchTasks _watch;
  TaskFilterEntity _filter;
  int _pages = 1;

  TasksCubit(this._watch, TaskFilterEntity initial) : _filter = initial;

  TaskFilterEntity get filter => _filter;

  /// Сколько задач сейчас запрашиваем.
  int get limit => kTasksPageSize * _pages;

  @override
  Stream<Either<Failure, List<TaskEntity>>> watchSource() =>
      _watch(_filter.copyWith(limit: limit, offset: 0));

  /// Новые фильтры: список перезапрашивается, старый остаётся на экране,
  /// пока приходит новый.
  void setFilter(TaskFilterEntity filter) {
    _filter = filter;
    _pages = 1;
    load(force: true, silent: true);
  }

  /// Пагинация: «Показать ещё».
  void loadMore() {
    _pages++;
    load(force: true, silent: true);
  }
}
