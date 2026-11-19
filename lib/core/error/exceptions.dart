/// Исключения Data Layer.
/// До экрана они не доходят: репозиторий превращает их в Failure.
class AppException implements Exception {
  final String? details;
  const AppException([this.details]);

  @override
  String toString() => '$runtimeType(${details ?? ''})';
}

/// Нет интернета, таймаут, обрыв соединения.
class NetworkException extends AppException {
  const NetworkException([super.details]);
}

/// Ответ сервера 401.
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.details]);
}

/// Ответ сервера 400.
class BadRequestException extends AppException {
  const BadRequestException([super.details]);
}

/// Ответ сервера 500 и другие ошибки сервера.
class ServerException extends AppException {
  final int? statusCode;
  const ServerException([super.details, this.statusCode]);
}

/// Ошибка локальной базы данных.
class CacheException extends AppException {
  const CacheException([super.details]);
}
