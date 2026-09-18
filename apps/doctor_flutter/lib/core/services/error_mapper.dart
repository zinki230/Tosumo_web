import 'package:dio/dio.dart';

sealed class AppFailure {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const AppFailure({
    required this.message,
    this.statusCode,
    this.originalError,
  });
}

class NetworkFailure extends AppFailure {
  const NetworkFailure({
    required super.message,
    super.statusCode,
    super.originalError,
  });
}

class AuthFailure extends AppFailure {
  const AuthFailure({
    required super.message,
    super.statusCode,
    super.originalError,
  });
}

class ValidationFailure extends AppFailure {
  final Map<String, List<String>>? errors;

  const ValidationFailure({
    required super.message,
    this.errors,
    super.statusCode,
    super.originalError,
  });
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    required super.message,
    super.statusCode,
    super.originalError,
  });
}

class ServerFailure extends AppFailure {
  const ServerFailure({
    required super.message,
    super.statusCode,
    super.originalError,
  });
}

class CacheFailure extends AppFailure {
  const CacheFailure({required super.message, super.originalError});
}

class ErrorMapper {
  static AppFailure fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure(
          message: 'Connection error. Please check your internet connection.',
          originalError: e,
        );
      case DioExceptionType.badResponse:
        return _fromStatusCode(e.response?.statusCode ?? 0, e);
      case DioExceptionType.cancel:
        return const NetworkFailure(message: 'Request was cancelled.');
      default:
        return NetworkFailure(
          message: e.message ?? 'An unexpected error occurred.',
          originalError: e,
        );
    }
  }

  static AppFailure _fromStatusCode(int statusCode, DioException e) {
    switch (statusCode) {
      case 400:
        return ValidationFailure(
          message: _messageFromResponse(
            e,
            'Invalid request. Please check your input.',
          ),
          errors: _errorsFromResponse(e),
          statusCode: statusCode,
          originalError: e,
        );
      case 401:
        return AuthFailure(
          message: _messageFromResponse(
            e,
            'Session expired. Please sign in again.',
          ),
          statusCode: statusCode,
          originalError: e,
        );
      case 403:
        return AuthFailure(
          message: _messageFromResponse(
            e,
            'You do not have permission to perform this action.',
          ),
          statusCode: statusCode,
          originalError: e,
        );
      case 404:
        return NotFoundFailure(
          message: _messageFromResponse(
            e,
            'The requested resource was not found.',
          ),
          statusCode: statusCode,
          originalError: e,
        );
      case 409:
        return ValidationFailure(
          message: _messageFromResponse(
            e,
            'This information is already registered.',
          ),
          errors: _errorsFromResponse(e),
          statusCode: statusCode,
          originalError: e,
        );
      case 422:
        return ValidationFailure(
          message: _messageFromResponse(e, 'Validation failed.'),
          errors: _errorsFromResponse(e),
          statusCode: statusCode,
          originalError: e,
        );
      case 429:
        return NetworkFailure(
          message: _messageFromResponse(
            e,
            'Too many requests. Please try again later.',
          ),
          statusCode: statusCode,
          originalError: e,
        );
      default:
        return ServerFailure(
          message: _messageFromResponse(
            e,
            'Server error. Please try again later.',
          ),
          statusCode: statusCode,
          originalError: e,
        );
    }
  }

  static String _messageFromResponse(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;

      final error = data['error'];
      if (error is String && error.trim().isNotEmpty) return error;

      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            final first = value.first;
            if (first is String && first.trim().isNotEmpty) return first;
          }
        }
      }
    }
    return fallback;
  }

  static Map<String, List<String>>? _errorsFromResponse(DioException e) {
    final data = e.response?.data;
    if (data is! Map || data['errors'] is! Map) return null;

    final parsed = <String, List<String>>{};
    (data['errors'] as Map).forEach((key, value) {
      if (value is List) {
        parsed[key.toString()] = value.whereType<String>().toList();
      } else if (value is String) {
        parsed[key.toString()] = [value];
      }
    });

    return parsed.isEmpty ? null : parsed;
  }

  static AppFailure fromException(dynamic e) {
    if (e is DioException) return fromDioException(e);
    if (e is AppFailure) return e;
    return ServerFailure(message: e.toString(), originalError: e);
  }
}
