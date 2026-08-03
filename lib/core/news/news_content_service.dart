import 'dart:convert';

import '../api_client.dart';
import '../api_config.dart';

abstract interface class NewsContentGateway {
  Future<NewsContentResult> load({required String id, required String url});
}

class NewsContentResult {
  const NewsContentResult({
    required this.content,
    required this.status,
    this.cached = false,
  });

  factory NewsContentResult.fromJson(Map<String, dynamic> json) {
    return NewsContentResult(
      content: sanitizeNewsContentText(json['content']?.toString() ?? ''),
      status: json['contentStatus']?.toString() ?? 'unavailable',
      cached: json['cached'] == true,
    );
  }

  final String content;
  final String status;
  final bool cached;

  bool get hasArticle =>
      (status == 'full' || status == 'partial') && content.isNotEmpty;
}

class ApiNewsContentGateway implements NewsContentGateway {
  const ApiNewsContentGateway();

  @override
  Future<NewsContentResult> load({
    required String id,
    required String url,
  }) async {
    final uri = Uri.parse('${ApiConfig.news}/content').replace(
      queryParameters: {
        if (id.trim().isNotEmpty) 'id': id.trim(),
        if (url.trim().isNotEmpty) 'url': url.trim(),
      },
    );
    final response = await ApiClient.get(
      uri,
      timeout: const Duration(seconds: 12),
      cacheTtl: const Duration(minutes: 10),
      retries: 0,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Tam metin servisi ${response.statusCode} döndürdü.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Geçersiz tam metin yanıtı.');
    }
    return NewsContentResult.fromJson(decoded);
  }
}

String sanitizeNewsContentText(String value) {
  return value
      .replaceAll(
        RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
      .trim();
}
