import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/news/news_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'share service sends only title and source URL to native channel',
    () async {
      const channel = MethodChannel('trendora.test/share');
      MethodCall? receivedCall;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            receivedCall = call;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final result = await NewsShareService(
        channel: channel,
      ).share(title: 'Güvenli haber başlığı', url: 'https://example.com/news');

      expect(result, NewsShareResult.shared);
      expect(receivedCall?.method, 'shareText');
      expect(receivedCall?.arguments, <String, String>{
        'text': 'Güvenli haber başlığı\nhttps://example.com/news',
      });
    },
  );
}
