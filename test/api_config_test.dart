import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/api_config.dart';

void main() {
  test('API endpoints use the configured base URL', () {
    expect(ApiConfig.news, '${ApiConfig.baseUrl}/api/news');
    expect(
      ApiConfig.opportunities,
      '${ApiConfig.baseUrl}/api/opportunities',
    );
    expect(ApiConfig.trends, '${ApiConfig.baseUrl}/api/trends');
    expect(ApiConfig.scanStatus, '${ApiConfig.baseUrl}/api/scan-status');
  });
}
