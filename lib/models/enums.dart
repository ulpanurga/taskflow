/// Перечисления предметной области.
/// В базе хранятся как текст (имя значения), например 'inProgress'.

enum ProjectStatus {
  active('Активный'),
  completed('Завершённый'),
  archived('Архивный');

  final String title;
  const ProjectStatus(this.title);
}

enum MemberRole {
  owner('Owner'),
  admin('Admin'),
  member('Member');

  final String title;
  const MemberRole(this.title);
}

enum TaskStatus {
  todo('Ожидает'),
  inProgress('Выполняется'),
  done('Завершена'),
  cancelled('Отменена');

  final String title;
  const TaskStatus(this.title);

  /// Задача считается незавершённой, если она ещё не done и не cancelled.
  bool get isOpen => this == todo || this == inProgress;
}

enum TaskPriority {
  low('Низкий'),
  medium('Средний'),
  high('Высокий'),
  critical('Критический');

  final String title;
  const TaskPriority(this.title);
}

/// Тип записи в истории задачи.
enum HistoryAction {
  created('Создана'),
  statusChanged('Смена статуса'),
  reassigned('Смена исполнителя'),
  undo('Отмена изменения'),
  restored('Восстановлена');

  final String title;
  const HistoryAction(this.title);
}
