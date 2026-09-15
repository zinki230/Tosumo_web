import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';
import 'error_interceptor.dart';
import 'token_storage_service.dart';
import '../network/doctor_api_endpoints.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({required TokenStorageService tokenStorage}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: DoctorApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      AuthInterceptor(tokenStorage),
      if (kDebugMode) LoggingInterceptor(),
      ErrorInterceptor(),
      _responseUnwrapperInterceptor(),
    ]);
  }

  Interceptor _responseUnwrapperInterceptor() {
    return InterceptorsWrapper(
      onResponse: (response, handler) {
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          if (data.containsKey('success') && data.containsKey('data')) {
            response.data = data['data'];
          }
        }
        handler.next(response);
      },
    );
  }

  Dio get dio => _dio;
}
