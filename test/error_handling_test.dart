import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/error_handler.dart';
import 'package:taskflow/core/error/exceptions.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/core/rest_client/api_client.dart';
import 'package:taskflow/models/remote_todo_model.dart';
import 'package:taskflow/src/data/datasources/remote/task_remote_datasource.dart';
import 'package:taskflow/src/data/repositories/other_repositories_impl.dart';

import 'test_env.dart';

class _FakeRemote implements TaskRemoteDataSource {
  Object? error;
  List<RemoteTodoModel> data = const [];

  @override
  Future<List<RemoteTodoModel>> getTodos({required int limit}) async {
    if (error != null) throw error!;
    return data;
  }
}

DioException _dioError(DioExceptionType type, {int? status, Object? error}) {
  final options = RequestOptions(path: '/todos');
  return DioException(
    requestOptions: options,
    type: type,
    error: error,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  group('Исключения -> Failure', () {
    test('22. Каждое исключение даёт свой Failure', () {
      expect(mapExceptionToFailure(const NetworkException()),
          isA<NetworkFailure>());
      expect(mapExceptionToFailure(const UnauthorizedException()),
          isA<UnauthorizedFailure>());
      expect(mapExceptionToFailure(const BadRequestException()),
          isA<ValidationFailure>());
      expect(mapExceptionToFailure(const ServerException('x', 500)),
          isA<ServerFailure>());
      expect(mapExceptionToFailure(const CacheException()),
          isA<CacheFailure>());
      expect(mapExceptionToFailure(StateError('что-то')),
          isA<UnknownFailure>());
    });

    test('23. Технический текст ошибки не попадает пользователю', () {
      final failure =
          mapExceptionToFailure(Exception('SECRET stack trace at line 42'));
      expect(failure.message, isNot(contains('SECRET')));
      expect(failure.message, isNot(contains('Exception')));

      final server = mapExceptionToFailure(
          const ServerException('DioException [500] internal', 500));
      expect(server.message, isNot(contains('Dio')));
    });
  });

  group('Ошибки Dio', () {
    test('24. 401, 400, 500 и сеть превращаются в нужные исключения', () {
      expect(mapDioException(_dioError(DioExceptionType.badResponse, status: 401)),
          isA<UnauthorizedException>());
      expect(mapDioException(_dioError(DioExceptionType.badResponse, status: 400)),
          isA<BadRequestException>());
      expect(mapDioException(_dioError(DioExceptionType.badResponse, status: 500)),
          isA<ServerException>());
      expect(mapDioException(_dioError(DioExceptionType.connectionTimeout)),
          isA<NetworkException>());
      expect(mapDioException(_dioError(DioExceptionType.connectionError)),
          isA<NetworkException>());
      expect(
          mapDioException(_dioError(DioExceptionType.unknown,
              error: const SocketException('нет сети'))),
          isA<NetworkException>());
    });
  });

  group('RemoteTodoRepository', () {
    late _FakeRemote remote;
    late RemoteTodoRepositoryImpl repo;

    setUp(() {
      remote = _FakeRemote();
      repo = RemoteTodoRepositoryImpl(remote);
    });

    test('25. Успех: модель превращается в Entity', () async {
      remote.data = const [
        RemoteTodoModel(id: 7, title: 'Задача', completed: true),
      ];
      final todos = ok(await repo.fetchTodos(limit: 5));
      expect(todos.single.id, 7);
      expect(todos.single.title, 'Задача');
      expect(todos.single.completed, isTrue);
    });

    test('26. Пустой ответ — это успех с пустым списком (Empty State)',
        () async {
      expect(ok(await repo.fetchTodos(limit: 5)), isEmpty);
    });

    test('27. Нет интернета, 401, 400, 500 и неизвестная ошибка', () async {
      final cases = <Object, Type>{
        const NetworkException(): NetworkFailure,
        const UnauthorizedException(): UnauthorizedFailure,
        const BadRequestException(): ValidationFailure,
        const ServerException('x', 500): ServerFailure,
        StateError('странно'): UnknownFailure,
      };
      for (final entry in cases.entries) {
        remote.error = entry.key;
        final failure = bad(await repo.fetchTodos(limit: 5));
        expect(failure.runtimeType, entry.value, reason: '${entry.key}');
      }
    });

    test('28. JSON из API разбирается в модель', () {
      final model = RemoteTodoModel.fromJson(
          {'userId': 1, 'id': 3, 'title': 'delectus', 'completed': false});
      expect(model.id, 3);
      expect(model.title, 'delectus');
      expect(model.completed, isFalse);
    });
  });
}
