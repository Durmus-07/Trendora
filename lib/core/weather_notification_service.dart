import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api_config.dart';

const _weatherTask = 'trendora_weather_change_check';
const _weatherEnabled = 'weather_notifications_enabled';
const _weatherLat = 'weather_last_latitude';
const _weatherLon = 'weather_last_longitude';
const _weatherName = 'weather_last_location_name';
const _weatherCode = 'weather_last_code';
const _weatherWarning = 'weather_last_warning';

final _notifications = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void weatherCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _weatherTask) return true;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_weatherEnabled) ?? false)) return true;
    final lat = prefs.getDouble(_weatherLat);
    final lon = prefs.getDouble(_weatherLon);
    if (lat == null || lon == null) return true;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/weather').replace(
        queryParameters: {
          'lat': '$lat',
          'lon': '$lon',
          'name': prefs.getString(_weatherName) ?? 'Konumum',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map) return false;
      if (data['stale'] == true || data['success'] == false) return true;
      final current = data['current'] is Map
          ? data['current'] as Map
          : const {};
      final warnings = data['warnings'] is List
          ? data['warnings'] as List
          : const [];
      final code = current['weatherCode'] is num
          ? (current['weatherCode'] as num).toInt()
          : null;
      final warning = warnings.isNotEmpty && warnings.first is Map
          ? '${(warnings.first as Map)['message'] ?? ''}'
          : '';
      final previousCode = prefs.getInt(_weatherCode);
      final previousWarning = prefs.getString(_weatherWarning) ?? '';
      final changed =
          previousCode != null && code != null && previousCode != code;
      final newWarning = warning.isNotEmpty && warning != previousWarning;
      if (changed || newWarning) {
        await WeatherNotificationService.initializeNotifications();
        final description = '${current['description'] ?? 'Hava değişti'}';
        final temperature = current['temperature'];
        await _notifications.show(
          id: 4101,
          title: newWarning ? 'Trendora hava uyarısı' : 'Hava durumu değişti',
          body: newWarning
              ? warning
              : '$description • ${temperature ?? '-'}° • ${prefs.getString(_weatherName) ?? 'Konumum'}',
          payload: jsonEncode({'type': 'weather', 'target': 'weatherCenter'}),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'trendora_weather_changes',
              'Hava değişiklikleri',
              channelDescription: 'Önemli hava değişimleri ve risk uyarıları',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
      if (code != null) await prefs.setInt(_weatherCode, code);
      await prefs.setString(_weatherWarning, warning);
      return true;
    } catch (_) {
      return false;
    }
  });
}

class WeatherNotificationService {
  WeatherNotificationService._();

  static Future<void> initialize({
    void Function(String? payload)? onNotificationPayload,
  }) async {
    await initializeNotifications(onNotificationPayload: onNotificationPayload);
    await Workmanager().initialize(weatherCallbackDispatcher);
  }

  static Future<void> initializeNotifications({
    void Function(String? payload)? onNotificationPayload,
  }) => _notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (response) =>
        onNotificationPayload?.call(response.payload),
  );

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_weatherEnabled) ?? false;

  static Future<bool> enable({
    required double latitude,
    required double longitude,
    required String locationName,
    int? currentCode,
    String warning = '',
  }) async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final allowed = await android?.requestNotificationsPermission() ?? true;
    if (!allowed) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weatherEnabled, true);
    await prefs.setDouble(_weatherLat, latitude);
    await prefs.setDouble(_weatherLon, longitude);
    await prefs.setString(_weatherName, locationName);
    if (currentCode != null) await prefs.setInt(_weatherCode, currentCode);
    await prefs.setString(_weatherWarning, warning);
    await Workmanager().registerPeriodicTask(
      _weatherTask,
      _weatherTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    await _notifications.show(
      id: 4100,
      title: 'Trendora hava bildirimleri açık',
      body: '$locationName için önemli hava değişiklikleri bildirilecek.',
      payload: jsonEncode({'type': 'weather', 'target': 'weatherCenter'}),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'trendora_weather_changes',
          'Hava değişiklikleri',
          channelDescription: 'Önemli hava değişimleri ve risk uyarıları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
    return true;
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weatherEnabled, false);
    await Workmanager().cancelByUniqueName(_weatherTask);
  }
}
