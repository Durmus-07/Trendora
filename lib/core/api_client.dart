import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiClient {
  ApiClient._();

  static const int _maxCacheItems = 64;
  static final Map<String, Future<http.Response>> _inFlight = {};
  static final Map<String, ({DateTime createdAt, http.Response response})> _cache = {};

  static const Map<String, String> jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=UTF-8',
  };

  static Future<http.Response> get(
    Uri uri, {
    Duration timeout = ApiConfig.requestTimeout,
    Duration cacheTtl = Duration.zero,
    int retries = 1,
  }) async {
    final key = uri.toString();
    final cached = _cache[key];
    if (cached != null) {
      final isFresh = cacheTtl > Duration.zero &&
          DateTime.now().difference(cached.createdAt) < cacheTtl;
      if (isFresh) return cached.response;
      _cache.remove(key);
    }
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final request = _getWithRetry(uri, timeout: timeout, retries: retries);
    _inFlight[key] = request;
    try {
      final response = await request;
      // Only callers that explicitly request caching should retain responses.
      if (cacheTtl > Duration.zero &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        if (_cache.length >= _maxCacheItems) {
          _cache.remove(_cache.keys.first);
        }
        _cache[key] = (createdAt: DateTime.now(), response: response);
      }
      return response;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<http.Response> _getWithRetry(
    Uri uri, {
    required Duration timeout,
    required int retries,
  }) async {
    final retryCount = retries.clamp(0, 2);
    Object? lastError;
    for (var attempt = 0; attempt <= retryCount; attempt++) {
      try {
        final response = await http
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(timeout);
        if (response.statusCode < 500 || attempt >= retryCount) return response;
      } catch (error) {
        lastError = error;
        if (attempt >= retryCount) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * (1 << attempt)));
    }
    throw lastError ?? StateError('HTTP isteği tamamlanamadı.');
  }

  static Future<http.Response> post(
    Uri uri, {
    Object? body,
    Duration timeout = ApiConfig.requestTimeout,
  }) {
    return http
        .post(uri, headers: jsonHeaders, body: body)
        .timeout(timeout);
  }
}
