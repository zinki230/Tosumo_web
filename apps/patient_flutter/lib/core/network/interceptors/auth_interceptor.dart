import 'package:dio/dio.dart';
import '../token_manager.dart';
import '../api_endpoints.dart';

/// Handles bearer-token attachment, transparent 401 refresh, and single-flight
/// retry of the original request.
///
/// Design notes:
///  * The refresh + retry are performed on a private internal [Dio] that only
///    carries the response-unwrapper interceptor (not this auth interceptor),
///    so retried responses are de-enveloped exactly like normal responses and
///    we never re-enter this interceptor recursively.
///  * Every branch resolves or forwards the request — a failed refresh never
///    leaves the original caller hanging.
///  * A single-flight lock (`_isRefreshing`) coalesces concurrent 401s so only
///    one refresh call hits the backend.
class AuthInterceptor extends Interceptor {
  final TokenManager _tokenManager;
  final String _baseUrl;

  AuthInterceptor(this._tokenManager, this._baseUrl);

  bool _isRefreshing = false;
  final _pendingRequests = <({RequestOptions options, ErrorInterceptorHandler handler})>[];

  Dio get _internalClient {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    dio.interceptors.add(_unwrapperInterceptor());
    return dio;
  }

  Interceptor _unwrapperInterceptor() {
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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.path.contains(ApiEndpoints.login) ||
        options.path.contains(ApiEndpoints.register) ||
        options.path.contains(ApiEndpoints.refresh)) {
      return handler.next(options);
    }

    final token = await _tokenManager.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    assert(() {
      // Debug-only observability; never logs the token value.
      // ignore: avoid_print
      print('[API AUTH] ${options.method} ${options.path} — Authorization attached: ${token != null && token.isNotEmpty}');
      return true;
    }());
    handler.next(options);
  }

  /// Normalizes the refresh response into a `{accessToken, refreshToken}` map
  /// regardless of envelope shape (the internal client already de-envelops).
  Map<String, dynamic> _tokensFromRefresh(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('accessToken')) return data;
      if (data.containsKey('tokens') && data['tokens'] is Map) {
        return data['tokens'] as Map<String, dynamic>;
      }
    }
    return {};
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // The refresh call itself failed — there is nothing to recover.
    if (err.requestOptions.path.contains(ApiEndpoints.refresh)) {
      await _tokenManager.clearTokens();
      return handler.next(err);
    }

    if (_isRefreshing) {
      _pendingRequests.add((options: err.requestOptions, handler: handler));
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _tokenManager.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _tokenManager.clearTokens();
        return handler.next(err);
      }

      final response = await _internalClient.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      final tokens = _tokensFromRefresh(response.data);
      final newToken = tokens['accessToken']?.toString();
      final newRefresh = tokens['refreshToken']?.toString();

      if (newToken == null || newToken.isEmpty || newRefresh == null || newRefresh.isEmpty) {
        await _tokenManager.clearTokens();
        return handler.next(err);
      }

      await _tokenManager.saveTokens(accessToken: newToken, refreshToken: newRefresh);
      // ignore: avoid_print
      print('[TOKEN] Access token refreshed & persisted');

      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final retryResponse = await _internalClient.fetch(err.requestOptions);
      handler.resolve(retryResponse);

      for (final pending in _pendingRequests) {
        pending.options.headers['Authorization'] = 'Bearer $newToken';
        try {
          final r = await _internalClient.fetch(pending.options);
          pending.handler.resolve(r);
        } catch (e) {
          pending.handler.next(e is DioException ? e : DioException(requestOptions: pending.options, error: e));
        }
      }
    } catch (_) {
      // ignore: avoid_print
      print('[TOKEN] Refresh failed — clearing session');
      await _tokenManager.clearTokens();
      handler.next(err);
      for (final pending in _pendingRequests) {
        pending.handler.next(err);
      }
    } finally {
      _isRefreshing = false;
      _pendingRequests.clear();
    }
  }
}
