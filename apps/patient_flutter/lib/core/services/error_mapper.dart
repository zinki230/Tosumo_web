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
  const CacheFailure({
    required super.message,
    super.originalError,
  });
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
          message: 'Invalid request. Please check your input.',
          statusCode: statusCode,
          originalError: e,
        );
      case 401:
        return AuthFailure(
          message: 'Session expired. Please sign in again.',
          statusCode: statusCode,
          originalError: e,
        );
      case 403:
        return AuthFailure(
          message: 'You do not have permission to perform this action.',
          statusCode: statusCode,
          originalError: e,
        );
      case 404:
        return NotFoundFailure(
          message: 'The requested resource was not found.',
          statusCode: statusCode,
          originalError: e,
        );
      case 422:
        return ValidationFailure(
          message: 'Validation failed.',
          statusCode: statusCode,
          originalError: e,
        );
      case 429:
        return NetworkFailure(
          message: 'Too many requests. Please try again later.',
          statusCode: statusCode,
          originalError: e,
        );
      default:
        return ServerFailure(
          message: 'Server error. Please try again later.',
          statusCode: statusCode,
          originalError: e,
        );
    }
  }

  static AppFailure fromException(dynamic e) {
    if (e is DioException) return fromDioException(e);
    if (e is AppFailure) return e;
    return ServerFailure(
      message: e.toString(),
      originalError: e,
    );
  }
}
