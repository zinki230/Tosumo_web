import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint('[HTTP] --> ${options.method} ${options.path}');
      debugPrint('[HTTP] Headers: ${options.headers}');
      if (options.data != null) {
        debugPrint('[HTTP] Body: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint('[HTTP] <-- ${response.statusCode} ${response.requestOptions.path}');
    }
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint('[HTTP] <-- ERROR ${err.response?.statusCode} ${err.requestOptions.path}');
      debugPrint('[HTTP] Error: ${err.message}');
    }
    handler.next(err);
  }
}
