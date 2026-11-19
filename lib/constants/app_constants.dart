/// Все «магические» значения проекта лежат здесь.

/// Максимум незавершённых задач у одного исполнителя на один день дедлайна.
const int kMaxOpenTasksPerDay = 3;

/// Тестовый API для импорта задач.
const String kApiBaseUrl = 'https://jsonplaceholder.typicode.com';

/// Сколько задач загружать с сервера за один раз.
const int kImportLimit = 20;

/// Сколько ждать ответ сервера.
const Duration kApiTimeout = Duration(seconds: 10);

/// Размер одной страницы в списке задач.
const int kTasksPageSize = 50;

final RegExp kEmailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
