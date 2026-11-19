import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/repositories/other_repositories.dart';
import 'package:taskflow/src/domain/usecases/stats_import_usecases.dart';
import 'package:taskflow/src/presentation/bloc/data_state.dart';
import 'package:taskflow/src/presentation/bloc/import_cubit.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

import 'test_env.dart';

class _TestCubit extends WatchCubit<List<int>> {
  final Stream<Either<Failure, List<int>>> Function() factory;
  int starts = 0;
  _TestCubit(this.factory);

  @override
  Stream<Either<Failure, List<int>>> watchSource() {
    starts++;
    return factory();
  }
}

class _FakeRemoteRepo implements RemoteTodoRepository {
  Either<Failure, List<RemoteTodo>> next = const Right([]);
  int calls = 0;

  @override
  Future<Either<Failure, List<RemoteTodo>>> fetchTodos(
      {required int limit}) async {
    calls++;
    return next;
  }
}

void main() {
  group('WatchCubit', () {
    test('29. Loading -> Success -> Empty -> Error', () async {
      final controller = StreamController<Either<Failure, List<int>>>();
      final cubit = _TestCubit(() => controller.stream);
      final states = <DataState<List<int>>>[];
      final sub = cubit.stream.listen(states.add);

      cubit.load();
      controller.add(const Right([1, 2]));
      await Future<void>.delayed(Duration.zero);
      controller.add(const Right([]));
      await Future<void>.delayed(Duration.zero);
      controller.add(const Left(NetworkFailure()));
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        const DataLoading<List<int>>(),
        const DataSuccess<List<int>>([1, 2]),
        const DataEmpty<List<int>>(),
        const DataError<List<int>>(NetworkFailure()),
      ]);

      await sub.cancel();
      await cubit.close();
      await controller.close();
    });

    test('30. Повторный load во время загрузки не создаёт второй запрос',
        () async {
      final controller = StreamController<Either<Failure, List<int>>>();
      final cubit = _TestCubit(() => controller.stream);

      cubit.load();
      cubit.load();
      cubit.load();
      expect(cubit.starts, 1);

      await cubit.close();
      await controller.close();
    });

    test('31. retry после ошибки запускает загрузку заново', () async {
      var attempt = 0;
      final cubit = _TestCubit(() {
        attempt++;
        return Stream.value(attempt == 1
            ? const Left(ServerFailure())
            : const Right([5]));
      });

      cubit.load();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const DataError<List<int>>(ServerFailure()));

      cubit.retry();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const DataSuccess<List<int>>([5]));
      expect(cubit.starts, 2);

      await cubit.close();
    });
  });

  group('ImportCubit', () {
    late TestEnv env;
    late _FakeRemoteRepo remote;
    late SessionCubit session;
    late ImportCubit cubit;
    late int projectId;
    late int userId;

    setUp(() async {
      env = TestEnv();
      remote = _FakeRemoteRepo();
      session = SessionCubit();
      final s = await env.basic();
      projectId = s.project;
      userId = s.user;
      cubit = ImportCubit(
          projectId, FetchRemoteTodos(remote), env.importTodos, session);
    });

    tearDown(() async {
      await cubit.close();
      await session.close();
      await env.close();
    });

    test('32. Загрузка, ошибка сети и повтор', () async {
      remote.next = const Left(NetworkFailure());
      await cubit.fetch();
      expect(cubit.state, const ImportError(NetworkFailure()));

      remote.next = const Right([
        RemoteTodo(id: 1, title: 'Задача 1', completed: false),
      ]);
      await cubit.retry();
      expect(cubit.state, isA<ImportLoaded>());
      expect(remote.calls, 2);
    });

    test('33. Пустой список с сервера — состояние Empty', () async {
      remote.next = const Right([]);
      await cubit.fetch();
      expect(cubit.state, isA<ImportEmpty>());
    });

    test('34. Второй запрос во время загрузки игнорируется', () async {
      remote.next = const Right([
        RemoteTodo(id: 1, title: 'Задача 1', completed: false),
      ]);
      await Future.wait([cubit.fetch(), cubit.fetch()]);
      expect(remote.calls, 1);
    });

    test('35. Сохранение упало — повтор сохраняет без нового запроса к серверу',
        () async {
      remote.next = const Right([
        RemoteTodo(id: 1, title: 'Задача 1', completed: false),
        RemoteTodo(id: 2, title: 'Задача 2', completed: true),
      ]);
      await cubit.fetch();

      // Текущий пользователь не выбран -> сохранить нельзя.
      await cubit.save();
      expect(cubit.state, isA<ImportError>());
      expect((cubit.state as ImportError).duringSave, isTrue);

      // Пользователь, которого нет в базе -> ошибка базы.
      session.setUser(9999);
      await cubit.retry();
      expect((cubit.state as ImportError).failure, isA<CacheFailure>());

      // Теперь всё правильно: повтор сохраняет те же задачи.
      session.setUser(userId);
      await cubit.retry();
      expect(cubit.state, const ImportSaved(2));
      expect(remote.calls, 1); // на сервер больше не ходили

      final saved = ok(await env.taskRepo
          .watchTasks(TaskFilterEntity(projectId: projectId))
          .first);
      expect(saved.length, 2);
    });
  });
}
