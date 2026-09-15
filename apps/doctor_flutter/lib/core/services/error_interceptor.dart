import 'package:dio/dio.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final error = _mapError(err);
    handler.next(error);
  }

  DioException _mapError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return DioException(
          requestOptions: err.requestOptions,
          type: err.type,
          message: 'La connexion a expiré. Veuillez réessayer.',
        );
      case DioExceptionType.connectionError:
        return DioException(
          requestOptions: err.requestOptions,
          type: err.type,
          message: 'Aucune connexion internet. Veuillez vérifier votre réseau.',
        );
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        if (statusCode == 500) {
          return DioException(
            requestOptions: err.requestOptions,
            type: err.type,
            message: 'Erreur serveur. Veuillez réessayer plus tard.',
            response: err.response,
          );
        }
        return err;
      default:
        return err;
    }
  }
}
