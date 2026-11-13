/// Ошибка бизнес-правил. Сообщение можно сразу показывать пользователю.
class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => message;
}
