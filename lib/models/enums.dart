// lib/models/enums.dart

enum ProjectStatus {
  active,
  paused,
  archived,
  completed;

  @override
  String toString() => name;
}

enum ParticipantRole {
  leader,
  worker,
  client,
  admin; // если добавил 'admin' в enum

  @override
  String toString() => name;
}

enum StageStatus {
  planned,
  in_progress,
  paused,
  completed;
}

enum WorkStatus {
  todo,
  in_progress,
  done,
  delayed;
}

enum CommentEntityType {
  project,
  stage,
  work;
}