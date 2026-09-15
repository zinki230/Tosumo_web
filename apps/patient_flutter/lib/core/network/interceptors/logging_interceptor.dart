import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[API] ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('[API] Body: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[API] ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final type = _typeLabel(err.type);
    final status = err.response?.statusCode;
    final url = err.requestOptions.uri;
    var body = '';
    if (err.response?.data != null) {
      final data = err.response!.data;
      body = ' | body=${data is String ? data : (data is Map ? data : data.toString())}';
    }
    debugPrint(
      '[API] ERROR ${err.requestOptions.method} $url: '
      'type=$type status=$status ${err.error ?? err.message}$body',
    );
    handler.next(err);
  }

  static String _typeLabel(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
        return 'connectionTimeout';
      case DioExceptionType.sendTimeout:
        return 'sendTimeout';
      case DioExceptionType.receiveTimeout:
        return 'receiveTimeout';
      case DioExceptionType.badCertificate:
        return 'badCertificate';
      case DioExceptionType.badResponse:
        return 'badResponse';
      case DioExceptionType.cancel:
        return 'cancel';
      case DioExceptionType.connectionError:
        return 'connectionError';
      case DioExceptionType.transformTimeout:
        return 'transformTimeout';
      case DioExceptionType.unknown:
        return 'unknown';
    }
  }
}
