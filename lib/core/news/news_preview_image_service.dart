import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

class NewsPreviewImageService {
  NewsPreviewImageService({
    http.Client? client,
    this.maxCacheEntries = 120,
    this.maxConcurrentRequests = 2,
    this.maxDocumentBytes = 96 * 1024,
    this.requestTimeout = const Duration(seconds: 4),
  }) : _client = client ?? http.Client();

  static final NewsPreviewImageService shared = NewsPreviewImageService();

  final http.Client _client;
  final int maxCacheEntries;
  final int maxConcurrentRequests;
  final int maxDocumentBytes;
  final Duration requestTimeout;
  final LinkedHashMap<String, Future<String?>> _cache = LinkedHashMap();
  final Queue<Completer<void>> _waiters = Queue();
  int _activeRequests = 0;

  Future<String?> resolvePreview(String articleUrl) {
    final uri = Uri.tryParse(articleUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return Future<String?>.value();
    }

    final key = uri.toString();
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final result = _withPermit(() => _loadPreview(uri));
    _cache[key] = result;
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return result;
  }

  Future<String?> _loadPreview(Uri articleUri) async {
    try {
      final request = http.Request('GET', articleUri)
        ..headers.addAll(const {
          'Accept': 'text/html,application/xhtml+xml',
          'Range': 'bytes=0-98303',
          'User-Agent': 'Trendora/1.0 NewsPreview',
        });
      final response = await _client.send(request).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 400) return null;

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.isNotEmpty &&
          !contentType.contains('text/html') &&
          !contentType.contains('application/xhtml')) {
        return null;
      }

      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(requestTimeout)) {
        final remaining = maxDocumentBytes - bytes.length;
        if (remaining <= 0) break;
        bytes.addAll(chunk.length <= remaining ? chunk : chunk.take(remaining));
        if (bytes.length >= maxDocumentBytes) break;
      }
      final html = utf8.decode(bytes, allowMalformed: true);
      return extractNewsPreviewImage(html, response.request?.url ?? articleUri);
    } catch (_) {
      return null;
    }
  }

  Future<T> _withPermit<T>(Future<T> Function() operation) async {
    if (_activeRequests >= maxConcurrentRequests) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _activeRequests += 1;
    try {
      return await operation();
    } finally {
      _activeRequests -= 1;
      if (_waiters.isNotEmpty) _waiters.removeFirst().complete();
    }
  }
}

String? extractNewsPreviewImage(String html, Uri baseUri) {
  if (html.trim().isEmpty) return null;
  final metadata = <String, String>{};
  final metaTags = RegExp(
    r'<meta\b[^>]*>',
    caseSensitive: false,
    multiLine: true,
  ).allMatches(html);
  final attributePattern = RegExp(
    r'''([\w:-]+)\s*=\s*(["'])(.*?)\2''',
    caseSensitive: false,
    dotAll: true,
  );

  for (final tagMatch in metaTags) {
    final attributes = <String, String>{};
    for (final attribute in attributePattern.allMatches(tagMatch.group(0)!)) {
      attributes[attribute.group(1)!.toLowerCase()] = attribute
          .group(3)!
          .trim();
    }
    final name =
        (attributes['property'] ?? attributes['name'] ?? attributes['itemprop'])
            ?.toLowerCase();
    final content = attributes['content'];
    if (name != null && content != null && content.isNotEmpty) {
      metadata.putIfAbsent(name, () => content);
    }
  }

  for (final key in const ['og:image', 'og:image:url']) {
    final resolved = _resolvePreviewUri(metadata[key], baseUri);
    if (resolved != null) return resolved;
  }
  for (final key in const ['twitter:image', 'twitter:image:src']) {
    final resolved = _resolvePreviewUri(metadata[key], baseUri);
    if (resolved != null) return resolved;
  }

  final schemaMeta = _resolvePreviewUri(metadata['image'], baseUri);
  if (schemaMeta != null) return schemaMeta;

  final scripts = RegExp(
    r'''<script\b[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
    caseSensitive: false,
  ).allMatches(html);
  for (final script in scripts) {
    try {
      final decoded = jsonDecode(script.group(1)!.trim());
      final candidate = _schemaImageValue(decoded);
      final resolved = _resolvePreviewUri(candidate, baseUri);
      if (resolved != null) return resolved;
    } catch (_) {
      // Geçersiz JSON-LD diğer önizleme adaylarını engellemez.
    }
  }
  return null;
}

String? _schemaImageValue(dynamic value) {
  if (value is Map) {
    if (value.containsKey('image')) {
      final image = _schemaImageCandidate(value['image']);
      if (image != null) return image;
    }
    for (final nested in value.values) {
      final candidate = _schemaImageValue(nested);
      if (candidate != null) return candidate;
    }
  } else if (value is List) {
    for (final nested in value) {
      final candidate = _schemaImageValue(nested);
      if (candidate != null) return candidate;
    }
  }
  return null;
}

String? _schemaImageCandidate(dynamic value) {
  if (value is String) return value;
  if (value is List) {
    for (final item in value) {
      final candidate = _schemaImageCandidate(item);
      if (candidate != null) return candidate;
    }
  }
  if (value is Map) {
    for (final key in const ['url', 'contentUrl', 'thumbnailUrl']) {
      final candidate = value[key];
      if (candidate is String && candidate.trim().isNotEmpty) return candidate;
    }
  }
  return null;
}

String? _resolvePreviewUri(String? value, Uri baseUri) {
  if (value == null || value.trim().isEmpty) return null;
  final decoded = value
      .trim()
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  final parsed = Uri.tryParse(decoded);
  if (parsed == null) return null;
  final resolved = baseUri.resolveUri(parsed);
  if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
  return resolved.toString();
}
