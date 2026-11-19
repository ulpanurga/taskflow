import 'dart:async';
import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';

import 'exceptions.dart';
import 'failures.dart';

/// Единственное место, где исключения превращаются в Failure.
/// Технический текст ошибки уходит только в лог.
Failure mapExceptionToFailure(
  Object error, {
  Failure fallback = const UnknownFailure(),
}) {
  if (error is Failure) return error;
  developer.log('Ошибка: $error', name: 'taskflow');

  if (error is NetworkException) return const NetworkFailure();
  if (error is UnauthorizedException) return const UnauthorizedFailure();
  if (error is BadRequestException) {
    return const ValidationFailure('Неверный запрос. Проверьте данные.');
  }
  if (error is ServerException) return const ServerFailure();
  if (error is CacheException) return const CacheFailure();
  return fallback;
}

/// Выполняет действие и возвращает Right(результат) или Left(Failure).
Future<Either<Failure, T>> guardCall<T>(
  Future<T> Function() body, {
  Failure fallback = const UnknownFailure(),
}) async {
  try {
    return Right<Failure, T>(await body());
  } catch (e) {
    return Left<Failure, T>(mapExceptionToFailure(e, fallback: fallback));
  }
}

/// То же самое для потоков (watch из Drift).
Stream<Either<Failure, T>> guardStream<T>(
  Stream<T> source, {
  Failure fallback = const UnknownFailure(),
}) {
  return source.transform(
    StreamTransformer<T, Either<Failure, T>>.fromHandlers(
      handleData: (data, sink) => sink.add(Right<Failure, T>(data)),
      handleError: (error, stack, sink) => sink.add(
          Left<Failure, T>(mapExceptionToFailure(error, fallback: fallback))),
    ),
  );
}
