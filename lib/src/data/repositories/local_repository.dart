import 'package:dartz/dartz.dart';
import 'package:taskflow/core/error/error_handler.dart';
import 'package:taskflow/core/error/failures.dart';

/// Базовый класс для репозиториев, которые работают с локальной базой.
/// Любая неожиданная ошибка здесь становится CacheFailure.
abstract class LocalRepository {
  const LocalRepository();

  Future<Either<Failure, T>> run<T>(Future<T> Function() body) =>
      guardCall(body, fallback: const CacheFailure());

  Stream<Either<Failure, T>> watch<T>(Stream<T> source) =>
      guardStream(source, fallback: const CacheFailure());
}
