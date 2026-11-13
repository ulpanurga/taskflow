import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/exceptions.dart';

/// В базе хранится только путь к файлу, а не его содержимое.
class AttachmentRepository {
  final AppDatabase _db;
  AttachmentRepository(this._db);

  Future<int> add(int taskId, String fileName, String filePath) async {
    final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
    if (task == null) {
      throw const ValidationException('Задача не найдена');
    }
    if (fileName.trim().isEmpty || filePath.trim().isEmpty) {
      throw const ValidationException('Не указан файл');
    }
    return _db.into(_db.attachments).insert(AttachmentsCompanion.insert(
          fileName: fileName,
          filePath: filePath,
          taskId: taskId,
        ));
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
  }

  Stream<List<Attachment>> watchForTask(int taskId) {
    return (_db.select(_db.attachments)
          ..where((a) => a.taskId.equals(taskId))
          ..orderBy([(a) => OrderingTerm.desc(a.addedAt)]))
        .watch();
  }
}
