import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Задача вместе с названием проекта и именем исполнителя.
class TaskEntity extends Equatable {
  final int id;
  final String title;
  final String description;
  final int projectId;
  final String projectName;
  final int? assigneeId;
  final String? assigneeName;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const TaskEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.projectId,
    required this.projectName,
    required this.assigneeId,
    required this.assigneeName,
    required this.priority,
    required this.status,
    required this.deadline,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  bool isOverdue(DateTime now) =>
      deadline != null && status.isOpen && deadline!.isBefore(now);

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        projectId,
        projectName,
        assigneeId,
        assigneeName,
        priority,
        status,
        deadline,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

/// Параметры списка задач: фильтры, сортировка, поиск, страница.
class TaskFilterEntity extends Equatable {
  final int? projectId;
  final TaskStatus? status;
  final TaskPriority? priority;
  final int? assigneeId;
  final String query;
  final TaskSort sortBy;
  final bool ascending;
  final int limit;
  final int offset;
  final bool onlyDeleted;

  const TaskFilterEntity({
    this.projectId,
    this.status,
    this.priority,
    this.assigneeId,
    this.query = '',
    this.sortBy = TaskSort.createdAt,
    this.ascending = false,
    this.limit = 50,
    this.offset = 0,
    this.onlyDeleted = false,
  });

  /// status, priority и assigneeId можно сбросить в null через clear*.
  TaskFilterEntity copyWith({
    int? projectId,
    TaskStatus? status,
    bool clearStatus = false,
    TaskPriority? priority,
    bool clearPriority = false,
    int? assigneeId,
    bool clearAssignee = false,
    String? query,
    TaskSort? sortBy,
    bool? ascending,
    int? limit,
    int? offset,
    bool? onlyDeleted,
  }) {
    return TaskFilterEntity(
      projectId: projectId ?? this.projectId,
      status: clearStatus ? null : (status ?? this.status),
      priority: clearPriority ? null : (priority ?? this.priority),
      assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
      query: query ?? this.query,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      onlyDeleted: onlyDeleted ?? this.onlyDeleted,
    );
  }

  @override
  List<Object?> get props => [
        projectId,
        status,
        priority,
        assigneeId,
        query,
        sortBy,
        ascending,
        limit,
        offset,
        onlyDeleted,
      ];
}

class CommentEntity extends Equatable {
  final int id;
  final int taskId;
  final int authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  const CommentEntity({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, taskId, authorId, authorName, body, createdAt];
}

class AttachmentEntity extends Equatable {
  final int id;
  final int taskId;
  final String fileName;
  final String filePath;
  final DateTime addedAt;

  const AttachmentEntity({
    required this.id,
    required this.taskId,
    required this.fileName,
    required this.filePath,
    required this.addedAt,
  });

  @override
  List<Object?> get props => [id, taskId, fileName, filePath, addedAt];
}

class HistoryEntryEntity extends Equatable {
  final int id;
  final int taskId;
  final HistoryAction action;
  final TaskStatus? oldStatus;
  final TaskStatus newStatus;
  final int? changedBy;
  final String? changedByName;
  final DateTime changedAt;
  final String? note;
  final bool isUndone;

  const HistoryEntryEntity({
    required this.id,
    required this.taskId,
    required this.action,
    required this.oldStatus,
    required this.newStatus,
    required this.changedBy,
    required this.changedByName,
    required this.changedAt,
    required this.note,
    required this.isUndone,
  });

  @override
  List<Object?> get props => [
        id,
        taskId,
        action,
        oldStatus,
        newStatus,
        changedBy,
        changedByName,
        changedAt,
        note,
        isUndone,
      ];
}

/// Задача, полученная с сервера (до сохранения в базу).
class RemoteTodo extends Equatable {
  final int id;
  final String title;
  final bool completed;

  const RemoteTodo({
    required this.id,
    required this.title,
    required this.completed,
  });

  @override
  List<Object?> get props => [id, title, completed];
}
