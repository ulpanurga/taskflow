import 'package:equatable/equatable.dart';

import 'enums.dart';

class UserEntity extends Equatable {
  final int id;
  final String name;
  final String email;
  final DateTime registeredAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.registeredAt,
  });

  @override
  List<Object?> get props => [id, name, email, registeredAt];
}

class ProjectEntity extends Equatable {
  final int id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final ProjectStatus status;

  const ProjectEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.finishedAt,
    required this.status,
  });

  @override
  List<Object?> get props =>
      [id, name, description, createdAt, finishedAt, status];
}

/// Участник проекта вместе с данными пользователя.
class MemberEntity extends Equatable {
  final int projectId;
  final int userId;
  final String userName;
  final String userEmail;
  final MemberRole role;

  const MemberEntity({
    required this.projectId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.role,
  });

  @override
  List<Object?> get props => [projectId, userId, userName, userEmail, role];
}
