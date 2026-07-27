class ApiConfig {
  ApiConfig._();

  // Trendora mobil uygulamasının tek üretim sunucusu.
  // USB testlerinde dahi localhost veya dart-define ile değiştirilmez.
  static const String baseUrl = 'https://trendora-icj9.onrender.com';

  static const String news = '$baseUrl/api/news';
  static const String opportunities = '$baseUrl/api/opportunities';
  static const String trends = '$baseUrl/api/trends';
  static const String scanStatus = '$baseUrl/api/scan-status';

  static const Duration requestTimeout =
      Duration(seconds: 60);
}
