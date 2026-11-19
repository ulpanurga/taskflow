import 'package:taskflow/core/error/exceptions.dart';
import 'package:taskflow/core/rest_client/api_client.dart';
import 'package:taskflow/models/remote_todo_model.dart';

/// Источник данных «сервер».
abstract class TaskRemoteDataSource {
  /// Бросает NetworkException, UnauthorizedException,
  /// BadRequestException или ServerException.
  Future<List<RemoteTodoModel>> getTodos({required int limit});
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final ApiClient _client;
  TaskRemoteDataSourceImpl(this._client);

  @override
  Future<List<RemoteTodoModel>> getTodos({required int limit}) async {
    final data = await _client.get('/todos', query: {'_limit': limit});
    if (data is! List) {
      // Сервер ответил не списком — это ошибка сервера.
      throw const ServerException('Неожиданный формат ответа');
    }
    try {
      return data
          .map((e) => RemoteTodoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const ServerException('Неожиданный формат элемента');
    }
  }
}
