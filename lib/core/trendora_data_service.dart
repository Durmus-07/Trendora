import 'dart:convert';

import 'api_client.dart';
import 'api_config.dart';
import 'api_models.dart';

class TrendoraDataService {
  const TrendoraDataService();

  Future<List<NewsData>> news({int limit = 100}) async {
    final uri = Uri.parse(ApiConfig.news).replace(queryParameters: {'limit': '$limit'});
    final response = await ApiClient.get(uri, cacheTtl: const Duration(minutes: 1));
    final body = _decode(response.body);
    return _items(body).map(NewsData.fromJson).toList(growable: false);
  }

  Future<List<OpportunityData>> opportunities({int limit = 100}) async {
    final uri = Uri.parse(ApiConfig.opportunities).replace(queryParameters: {'limit': '$limit'});
    final response = await ApiClient.get(uri, cacheTtl: const Duration(minutes: 2));
    final body = _decode(response.body);
    return _items(body).map(OpportunityData.fromJson).toList(growable: false);
  }

  Future<List<FinancialData>> marketBoard() async {
    final response = await ApiClient.get(
      Uri.parse('${ApiConfig.trends}/market-board'),
      cacheTtl: const Duration(minutes: 2),
    );
    return _items(_decode(response.body)).map(FinancialData.fromJson).toList(growable: false);
  }

  Map<String, dynamic> _decode(String body) => (jsonDecode(body) as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> _items(Map<String, dynamic> body) =>
      (body['items'] as List? ?? const []).whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
}
