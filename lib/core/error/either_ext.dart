import 'package:dartz/dartz.dart';

import 'failures.dart';

extension EitherChain<L, R> on Either<L, R> {
  /// Если слева ошибка — возвращает её, иначе вызывает следующий шаг.
  Future<Either<L, T>> thenAsync<T>(
      Future<Either<L, T>> Function(R value) next) {
    return fold<Future<Either<L, T>>>(
      (l) async => Left<L, T>(l),
      (r) => next(r),
    );
  }
}

extension EitherFailureX<R> on Either<Failure, R> {
  /// Ошибка или null, если всё прошло хорошо.
  Failure? get failureOrNull => fold<Failure?>((f) => f, (_) => null);
}
