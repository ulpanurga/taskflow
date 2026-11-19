import 'package:taskflow/models/dashboard_stats_model.dart';
import 'package:taskflow/models/remote_todo_model.dart';
import 'package:taskflow/src/data/datasources/local/app_database.dart';
import 'package:taskflow/src/data/datasources/local/other_local_datasources.dart';
import 'package:taskflow/src/data/datasources/local/project_local_datasource.dart';
import 'package:taskflow/src/data/datasources/local/task_local_datasource.dart';
import 'package:taskflow/src/domain/entities/dashboard_stats_entity.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/entities/user_project_entities.dart';

/// Преобразование моделей Data Layer (строки Drift, DTO) в Entity.
/// В Presentation Layer попадают только Entity.

extension UserRowMapper on User {
  UserEntity toEntity() => UserEntity(
        id: id,
        name: name,
        email: email,
        registeredAt: registeredAt,
      );
}

extension ProjectRowMapper on Project {
  ProjectEntity toEntity() => ProjectEntity(
        id: id,
        name: name,
        description: description,
        createdAt: createdAt,
        finishedAt: finishedAt,
        status: status,
      );
}

extension MemberRowMapper on MemberRow {
  MemberEntity toEntity() => MemberEntity(
        projectId: member.projectId,
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        role: member.role,
      );
}

extension TaskRowMapper on TaskRow {
  TaskEntity toEntity() => TaskEntity(
        id: task.id,
        title: task.title,
        description: task.description,
        projectId: task.projectId,
        projectName: project.name,
        assigneeId: task.assigneeId,
        assigneeName: assignee?.name,
        priority: task.priority,
        status: task.status,
        deadline: task.deadline,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        deletedAt: task.deletedAt,
      );
}

extension HistoryRowMapper on HistoryRow {
  HistoryEntryEntity toEntity() => HistoryEntryEntity(
        id: entry.id,
        taskId: entry.taskId,
        action: entry.action,
        oldStatus: entry.oldStatus,
        newStatus: entry.newStatus,
        changedBy: entry.changedBy,
        changedByName: user?.name,
        changedAt: entry.changedAt,
        note: entry.note,
        isUndone: entry.isUndone,
      );
}

extension HistoryEntryMapper on HistoryEntry {
  HistoryEntryEntity toEntity() => HistoryEntryEntity(
        id: id,
        taskId: taskId,
        action: action,
        oldStatus: oldStatus,
        newStatus: newStatus,
        changedBy: changedBy,
        changedByName: null,
        changedAt: changedAt,
        note: note,
        isUndone: isUndone,
      );
}

extension CommentRowMapper on CommentRow {
  CommentEntity toEntity() => CommentEntity(
        id: comment.id,
        taskId: comment.taskId,
        authorId: comment.authorId,
        authorName: author.name,
        body: comment.body,
        createdAt: comment.createdAt,
      );
}

extension AttachmentRowMapper on Attachment {
  AttachmentEntity toEntity() => AttachmentEntity(
        id: id,
        taskId: taskId,
        fileName: fileName,
        filePath: filePath,
        addedAt: addedAt,
      );
}

extension DashboardStatsMapper on DashboardStatsModel {
  DashboardStatsEntity toEntity() {
    return DashboardStatsEntity(
      projects: projects,
      tasks: tasks,
      done: done,
      notDone: notDone,
      overdue: overdue,
      byPriority: {
        for (final p in TaskPriority.values) p: byPriority[p.name] ?? 0,
      },
      byAssignee:
          byAssignee.map((a) => AssigneeCountEntity(a.name, a.count)).toList(),
      projectProgress: projectProgress
          .map((p) => ProjectProgressEntity(
              p.projectId, p.name, p.total, p.done, p.percent))
          .toList(),
    );
  }
}

extension RemoteTodoMapper on RemoteTodoModel {
  RemoteTodo toEntity() =>
      RemoteTodo(id: id, title: title, completed: completed);
}
