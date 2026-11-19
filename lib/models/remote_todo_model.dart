/// DTO: так задача приходит с сервера (jsonplaceholder /todos).
/// Эта модель живёт только в Data Layer. До экранов она не доходит:
/// репозиторий превращает её в RemoteTodo (Entity).
class RemoteTodoModel {
  final int id;
  final String title;
  final bool completed;

  const RemoteTodoModel({
    required this.id,
    required this.title,
    required this.completed,
  });

  factory RemoteTodoModel.fromJson(Map<String, dynamic> json) {
    return RemoteTodoModel(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      completed: (json['completed'] ?? false) as bool,
    );
  }
}
