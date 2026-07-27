import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiClient {
  ApiClient._();

  static const Map<String, String> jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=UTF-8',
  };

  static Future<http.Response> get(
    Uri uri, {
    Duration timeout = ApiConfig.requestTimeout,
  }) {
    return http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(timeout);
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
