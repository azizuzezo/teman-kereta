import 'dart:async';

import 'package:dio/dio.dart';

import '../../app/config/app_environment.dart';

class ApiClient {
  factory ApiClient.localOnly() {
    AppEnvironment.validateLocalOnly();
    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnvironment.apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 8),
        headers: const <String, String>{'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(_LocalRetryInterceptor(dio));
    return ApiClient._(dio);
  }
  ApiClient._(this.dio);

  final Dio dio;
}

class _LocalRetryInterceptor extends Interceptor {
  _LocalRetryInterceptor(this.dio);

  final Dio dio;

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final retries = request.extra['retries'] as int? ?? 0;
    final retryable =
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.response?.statusCode ?? 0) >= 500;
    if (!retryable || retries >= 2 || request.method != 'GET') {
      handler.next(error);
      return;
    }

    await Future<void>.delayed(Duration(milliseconds: 250 * (retries + 1)));
    request.extra['retries'] = retries + 1;
    try {
      handler.resolve(await dio.fetch<Object?>(request));
    } on DioException catch (nextError) {
      handler.next(nextError);
    }
  }
}
