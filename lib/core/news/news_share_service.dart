import 'package:flutter/services.dart';

enum NewsShareResult { shared, copiedToClipboard }

class NewsShareService {
  NewsShareService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.durmus.trendora/share';

  final MethodChannel _channel;

  Future<NewsShareResult> share({
    required String title,
    required String url,
  }) async {
    final shareText = [
      title.trim(),
      url.trim(),
    ].where((part) => part.isNotEmpty).join('\n');

    if (shareText.isEmpty) {
      throw const FormatException('Paylaşılacak haber bilgisi bulunamadı.');
    }

    try {
      await _channel.invokeMethod<void>('shareText', <String, String>{
        'text': shareText,
      });
      return NewsShareResult.shared;
    } on MissingPluginException {
      return _copyToClipboard(shareText);
    } on PlatformException {
      return _copyToClipboard(shareText);
    }
  }

  Future<NewsShareResult> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    return NewsShareResult.copiedToClipboard;
  }
}
