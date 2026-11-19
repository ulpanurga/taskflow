import 'package:equatable/equatable.dart';

import 'enums.dart';

class AssigneeCountEntity extends Equatable {
  final String name;
  final int count;
  const AssigneeCountEntity(this.name, this.count);

  @override
  List<Object?> get props => [name, count];
}

class ProjectProgressEntity extends Equatable {
  final int projectId;
  final String name;
  final int total;
  final int done;
  final double percent;
  const ProjectProgressEntity(
      this.projectId, this.name, this.total, this.done, this.percent);

  @override
  List<Object?> get props => [projectId, name, total, done, percent];
}

class DashboardStatsEntity extends Equatable {
  final int projects;
  final int tasks;
  final int done;
  final int notDone;
  final int overdue;
  final Map<TaskPriority, int> byPriority;
  final List<AssigneeCountEntity> byAssignee;
  final List<ProjectProgressEntity> projectProgress;

  const DashboardStatsEntity({
    required this.projects,
    required this.tasks,
    required this.done,
    required this.notDone,
    required this.overdue,
    required this.byPriority,
    required this.byAssignee,
    required this.projectProgress,
  });

  @override
  List<Object?> get props => [
        projects,
        tasks,
        done,
        notDone,
        overdue,
        byPriority,
        byAssignee,
        projectProgress,
      ];
}
