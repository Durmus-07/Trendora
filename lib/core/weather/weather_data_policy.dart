import 'package:geolocator/geolocator.dart';

class WeatherDataPolicy {
  WeatherDataPolicy._();

  static const cacheTtl = Duration(minutes: 15);
  static const staleAfter = Duration(minutes: 30);

  static double approximateCoordinate(double value) =>
      (value * 100).roundToDouble() / 100;

  static bool shouldUseCityFallback(LocationPermission permission) =>
      permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever;

  static DateTime? updatedAt(Map<String, dynamic> data) {
    final raw = data['dataTime'] ?? data['updatedAt'];
    return raw == null ? null : DateTime.tryParse('$raw')?.toLocal();
  }

  static bool isStale(Map<String, dynamic> data, {DateTime? now}) {
    final updateTime = updatedAt(data);
    if (updateTime == null) return true;
    return (now ?? DateTime.now()).difference(updateTime) > staleAfter;
  }

  static String sourceName(Map<String, dynamic> data) {
    final sourceInfo = data['sourceInfo'];
    if (sourceInfo is Map) {
      final name = '${sourceInfo['name'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    final source = '${data['source'] ?? ''}'.trim();
    return source.isEmpty ? 'Bilinmiyor' : source;
  }

  static String updatedLabel(Map<String, dynamic> data) {
    final value = updatedAt(data);
    if (value == null) return 'Güncelleme zamanı bilinmiyor';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year} $hour:$minute';
  }
}
