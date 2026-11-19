import 'package:equatable/equatable.dart';

/// Ошибки, которые видят Domain и Presentation.
/// В `message` всегда лежит понятный пользователю текст,
/// технические подробности сюда не попадают.
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Нет интернета.
class NetworkFailure extends Failure {
  const NetworkFailure(
      [super.message =
          'Нет подключения к интернету. Проверьте сеть и повторите попытку.']);
}

/// Ошибка сервера (500 и подобные).
class ServerFailure extends Failure {
  const ServerFailure(
      [super.message = 'Ошибка на сервере. Попробуйте чуть позже.']);
}

/// Ошибка авторизации (401).
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(
      [super.message = 'Нужно войти в аккаунт, чтобы продолжить.']);
}

/// Неверный запрос (400) или нарушено правило приложения.
/// Текст в `message` пишем сами, поэтому его можно показывать.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Ошибка локальной базы данных.
class CacheFailure extends Failure {
  const CacheFailure(
      [super.message = 'Не удалось прочитать или сохранить данные на устройстве.']);
}

/// Что-то неожиданное.
class UnknownFailure extends Failure {
  const UnknownFailure(
      [super.message = 'Что-то пошло не так. Попробуйте ещё раз.']);
}
