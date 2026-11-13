import '../database/app_database.dart';
import 'enums.dart';

/// Задача вместе с названием проекта и именем исполнителя.
class TaskView {
  final Task task;
  final Project project;
  final User? assignee;
  const TaskView(this.task, this.project, this.assignee);
}

class MemberView {
  final ProjectMember member;
  final User user;
  const MemberView(this.member, this.user);
}

class CommentView {
  final Comment comment;
  final User author;
  const CommentView(this.comment, this.author);
}

class HistoryView {
  final HistoryEntry entry;
  final User? user;
  const HistoryView(this.entry, this.user);
}

enum TaskSort { createdAt, deadline }

/// Параметры фильтрации, сортировки, поиска и пагинации списка задач.
class TaskFilter {
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

  const TaskFilter({
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

  /// Поля status/priority/assigneeId можно сбросить в null,
  /// поэтому для них используются отдельные флаги clear*.
  TaskFilter copyWith({
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
    return TaskFilter(
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
}

class AssigneeCount {
  final String name;
  final int count;
  const AssigneeCount(this.name, this.count);
}

class ProjectProgress {
  final int projectId;
  final String name;
  final int total;
  final int done;
  final double percent;
  const ProjectProgress(this.projectId, this.name, this.total, this.done, this.percent);
}

/// Данные для экрана статистики. Всё считается SQL-запросами.
class DashboardStats {
  final int projects;
  final int tasks;
  final int done;
  final int notDone;
  final int overdue;
  final Map<TaskPriority, int> byPriority;
  final List<AssigneeCount> byAssignee;
  final List<ProjectProgress> projectProgress;

  const DashboardStats({
    required this.projects,
    required this.tasks,
    required this.done,
    required this.notDone,
    required this.overdue,
    required this.byPriority,
    required this.byAssignee,
    required this.projectProgress,
  });
}
