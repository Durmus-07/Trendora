import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/bildirim_ayarlari_sayfasi.dart';
import 'package:trendora_app/core/notifications/smart_notification_engine.dart';
import 'package:trendora_app/core/weather_notification_service.dart';

void main() {
  const userId = 'guest:notification-settings-test';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trendora_anonymous_user_id_v1': userId,
    });
  });

  testWidgets('permission is requested only after an explicit enable action', (
    tester,
  ) async {
    var permissionRequests = 0;
    await tester.pumpWidget(
      _app(() async {
        permissionRequests++;
        return false;
      }),
    );
    await tester.pumpAndSettle();

    expect(permissionRequests, 0);
    await tester.tap(find.text('Desteklenen tüm bildirimleri aç'));
    await tester.pumpAndSettle();

    final preferences = await _loadPreferences(userId);
    expect(permissionRequests, 1);
    expect(preferences.enabled, isFalse);
    expect(preferences.categories, isEmpty);
  });

  testWidgets('enable all selects only categories with real producers', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() async => true));
    await tester.pumpAndSettle();

    expect(find.text('Piyasa alarmları'), findsNothing);
    expect(find.text('Trendora duyuruları'), findsNothing);
    await tester.tap(find.text('Desteklenen tüm bildirimleri aç'));
    await tester.pumpAndSettle();

    final preferences = await _loadPreferences(userId);
    expect(preferences.enabled, isTrue);
    expect(preferences.categories, supportedSmartNotificationCategories);
  });

  testWidgets('disabling notifications persists the preference', (
    tester,
  ) async {
    final shared = await SharedPreferences.getInstance();
    await SharedPreferencesSmartNotificationStore(shared).savePreferences(
      userId,
      const SmartNotificationPreferences(
        enabled: true,
        categories: supportedSmartNotificationCategories,
      ),
    );
    await tester.pumpWidget(_app(() async => true));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Akıllı bildirimleri aç'),
    );
    await tester.pumpAndSettle();

    expect((await _loadPreferences(userId)).enabled, isFalse);
  });

  test('weather notification preference remains independent', () async {
    SharedPreferences.setMockInitialValues({
      'weather_notifications_enabled': true,
    });
    expect(await WeatherNotificationService.isEnabled(), isTrue);

    SharedPreferences.setMockInitialValues({
      'weather_notifications_enabled': false,
    });
    expect(await WeatherNotificationService.isEnabled(), isFalse);
  });
}

Widget _app(Future<bool> Function() permissionRequester) {
  return MaterialApp(
    home: BildirimAyarlariSayfasi(
      notificationPermissionRequester: permissionRequester,
    ),
  );
}

Future<SmartNotificationPreferences> _loadPreferences(String userId) async {
  final shared = await SharedPreferences.getInstance();
  return SharedPreferencesSmartNotificationStore(
    shared,
  ).loadPreferences(userId);
}
