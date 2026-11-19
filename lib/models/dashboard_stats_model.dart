/// Модель статистики: так её возвращает SQL (приоритеты — строками).
class AssigneeCountModel {
  final String name;
  final int count;
  const AssigneeCountModel(this.name, this.count);
}

class ProjectProgressModel {
  final int projectId;
  final String name;
  final int total;
  final int done;
  final double percent;
  const ProjectProgressModel(
      this.projectId, this.name, this.total, this.done, this.percent);
}

class DashboardStatsModel {
  final int projects;
  final int tasks;
  final int done;
  final int notDone;
  final int overdue;
  final Map<String, int> byPriority;
  final List<AssigneeCountModel> byAssignee;
  final List<ProjectProgressModel> projectProgress;

  const DashboardStatsModel({
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
