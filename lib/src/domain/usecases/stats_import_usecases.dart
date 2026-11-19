import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/either_ext.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/dashboard_stats_entity.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/other_repositories.dart';
import 'package:taskflow/src/domain/repositories/task_repository.dart';

class WatchDashboardStats {
  final StatsRepository _repo;
  const WatchDashboardStats(this._repo);

  Stream<Either<Failure, DashboardStatsEntity>> call() => _repo.watchStats();
}

/// Новая функция СРС 11: загрузка списка задач с сервера.
class FetchRemoteTodos {
  final RemoteTodoRepository _repo;
  const FetchRemoteTodos(this._repo);

  Future<Either<Failure, List<RemoteTodo>>> call({required int limit}) =>
      _repo.fetchTodos(limit: limit);
}

/// Сохраняет загруженные задачи в локальную базу.
/// Задачи, которые уже есть в проекте (по названию), пропускаются.
class ImportTodos {
  final TaskRepository _tasks;
  const ImportTodos(this._tasks);

  /// Возвращает, сколько задач добавлено.
  Future<Either<Failure, int>> call({
    required int projectId,
    required int actorId,
    required List<RemoteTodo> todos,
  }) async {
    if (todos.isEmpty) {
      return const Left(ValidationFailure('Нечего импортировать'));
    }
    final existing = await _tasks.existingTitles(projectId);
    return existing.thenAsync<int>((titles) async {
      final seen = {...titles};
      final fresh = <RemoteTodo>[];
      for (final todo in todos) {
        final title = todo.title.trim();
        if (title.isEmpty || seen.contains(title)) continue;
        seen.add(title);
        fresh.add(todo);
      }
      if (fresh.isEmpty) {
        return const Left(
            ValidationFailure('Все эти задачи уже есть в проекте'));
      }
      return _tasks.addImportedTasks(
        projectId: projectId,
        actorId: actorId,
        todos: fresh,
      );
    });
  }
}
