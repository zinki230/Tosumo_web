import 'package:dio/dio.dart';
import 'token_storage_service.dart';
import '../network/doctor_api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorageService _tokenStorage;

  AuthInterceptor(this._tokenStorage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Never auto-refresh the refresh or logout calls themselves: doing so
      // would recurse and/or rotate the token a second time with a stale one.
      if (err.requestOptions.path.endsWith(DoctorApiEndpoints.refresh) ||
          err.requestOptions.path.endsWith(DoctorApiEndpoints.logout)) {
        handler.next(err);
        return;
      }
      await _refreshAndRetry(err, handler);
      return;
    }
    handler.next(err);
  }

  Future<void> _refreshAndRetry(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      // Always read the freshest refresh token *inside* the locked section:
      // concurrent 401s share a single rotation and never race with a stale
      // token (which the server would reject as revoked and wipe the session).
      await _tokenStorage.runRefreshLocked(() => _doRefresh());
      final newToken = await _tokenStorage.getToken();
      if (newToken == null || newToken.isEmpty) {
        await _tokenStorage.clearAll();
        handler.next(err);
        return;
      }

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';
      final retryClient = Dio(BaseOptions(baseUrl: DoctorApiEndpoints.baseUrl));
      final retryResponse = await retryClient.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (refreshError) {
      // Only drop the session when the server explicitly rejects the request
      // (401 = genuinely revoked/expired). Transient network/timeout errors
      // must not destroy a stored session.
      if (refreshError is DioException &&
          refreshError.response?.statusCode == 401) {
        await _tokenStorage.clearAll();
      }
      handler.next(err);
    }
  }

  Future<void> _doRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: DoctorApiEndpoints.refresh),
        response: Response(
          requestOptions: RequestOptions(path: DoctorApiEndpoints.refresh),
          statusCode: 401,
        ),
      );
    }
    final refreshClient = Dio(BaseOptions(baseUrl: DoctorApiEndpoints.baseUrl));
    final response = await refreshClient.post(
      DoctorApiEndpoints.refresh,
      data: {'refreshToken': refreshToken},
    );
    final responseData = response.data is Map<String, dynamic>
        ? (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    final tokens = responseData['tokens'] as Map<String, dynamic>?;
    final newToken = tokens?['accessToken'] as String? ?? responseData['accessToken'] as String?;
    final newRefreshToken = tokens?['refreshToken'] as String? ?? responseData['refreshToken'] as String?;
    if (newToken == null || newRefreshToken == null) {
      throw DioException(
        requestOptions: RequestOptions(path: DoctorApiEndpoints.refresh),
        response: Response(
          requestOptions: RequestOptions(path: DoctorApiEndpoints.refresh),
          statusCode: 401,
        ),
      );
    }
    await _tokenStorage.saveTokens(accessToken: newToken, refreshToken: newRefreshToken);
  }
}
