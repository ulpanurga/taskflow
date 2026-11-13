import 'package:flutter/foundation.dart';

import '../models/views.dart';
import '../repositories/task_repository.dart';

/// Состояние списка задач: фильтры, сортировка, поиск, пагинация.
/// Список берётся из Drift через watch(), поэтому обновляется сам.
class TasksController extends ChangeNotifier {
  TasksController(this._repo, {TaskFilter initial = const TaskFilter()})
      : _filter = initial {
    _rebuild();
  }

  static const int pageSize = 50;

  final TaskRepository _repo;
  TaskFilter _filter;
  int _pages = 1;
  late Stream<List<TaskView>> _stream;

  TaskFilter get filter => _filter;
  int get limit => pageSize * _pages;
  Stream<List<TaskView>> get stream => _stream;

  void _rebuild() {
    _stream = _repo.watchTasks(_filter.copyWith(limit: limit, offset: 0));
  }

  void update(TaskFilter f) {
    _filter = f;
    _pages = 1;
    _rebuild();
    notifyListeners();
  }

  /// Пагинация: «Показать ещё» увеличивает размер страницы.
  void loadMore() {
    _pages++;
    _rebuild();
    notifyListeners();
  }
}
