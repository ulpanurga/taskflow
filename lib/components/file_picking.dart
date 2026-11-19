import 'package:file_picker/file_picker.dart';

/// Выбор файла на устройстве. Возвращает имя и путь или null.
/// Код написан так, чтобы работать в разных версиях file_picker.
Future<({String name, String path})?> pickLocalFile() async {
  final dynamic res = await FilePicker.pickFiles();
  final dynamic file = res == null
      ? null
      : (res is List ? (res.isEmpty ? null : res.first) : res.files.first);
  final String? path = file?.path as String?;
  final String? name = file?.name as String?;
  if (path == null || name == null) return null;
  return (name: name, path: path);
}
