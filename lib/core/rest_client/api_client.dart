import 'dart:io';

import 'package:dio/dio.dart';
import 'package:taskflow/constants/app_constants.dart';
import 'package:taskflow/core/error/exceptions.dart';

/// Превращает ошибку Dio в наше исключение Data Layer.
AppException mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return NetworkException(e.message);
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      if (code == 401) return UnauthorizedException(e.message);
      if (code == 400) return BadRequestException(e.message);
      return ServerException(e.message, code);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      if (e.error is SocketException) return NetworkException(e.message);
      return AppException(e.message);
  }
}

/// Единый HTTP-клиент. Все ошибки Dio выходят отсюда уже как AppException.
class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  factory ApiClient.create() {
    return ApiClient(Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: kApiTimeout,
      receiveTimeout: kApiTimeout,
      headers: {'Accept': 'application/json'},
    )));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      return response.data;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}