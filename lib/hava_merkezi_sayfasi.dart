import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/api_config.dart';
import 'core/weather_notification_service.dart';

class HavaMerkeziSayfasi extends StatefulWidget {
  const HavaMerkeziSayfasi({super.key});

  @override
  State<HavaMerkeziSayfasi> createState() => _HavaMerkeziSayfasiState();
}

class _HavaMerkeziSayfasiState extends State<HavaMerkeziSayfasi> {
  final _arama = TextEditingController(text: 'İstanbul');
  bool _yukleniyor = false;
  String? _hata;
  Map<String, dynamic>? _hava;
  bool _bildirimlerAcik = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _bildirimlerAcik = await WeatherNotificationService.isEnabled();
      if (mounted) setState(() {});
      await _konumuBul();
    });
  }

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _sehriGetir() async {
    final query = _arama.text.trim();
    if (query.length < 2 || _yukleniyor) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _yukleniyor = true; _hata = null; });
    try {
      final searchUri = Uri.parse('${ApiConfig.baseUrl}/api/weather/search')
          .replace(queryParameters: {'q': query});
      final searchResponse = await ApiClient.get(searchUri);
      final search = jsonDecode(utf8.decode(searchResponse.bodyBytes));
      final results = search is Map ? search['results'] : null;
      if (searchResponse.statusCode != 200 || results is! List || results.isEmpty) {
        throw Exception('Şehir bulunamadı. İl veya ilçe adını kontrol et.');
      }
      final place = Map<String, dynamic>.from(results.first as Map);
      final weatherUri = Uri.parse('${ApiConfig.baseUrl}/api/weather').replace(
        queryParameters: {
          'lat': '${place['latitude']}',
          'lon': '${place['longitude']}',
          'name': '${place['label'] ?? place['name']}',
        },
      );
      final response = await ApiClient.get(weatherUri);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || decoded is! Map) {
        throw Exception('Hava verisi şu anda alınamadı.');
      }
      if (mounted) setState(() => _hava = Map<String, dynamic>.from(decoded));
      await _havaKartiKaydet(Map<String, dynamic>.from(decoded));
      if (_bildirimlerAcik) await _bildirimTercihiniDegistir(true, sessiz: true);
    } catch (error) {
      if (mounted) setState(() => _hata = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _konumuBul() async {
    if (_yukleniyor) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Otomatik konum için telefonun konum servisini aç.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni verilmedi. İstersen şehir adını elle arayabilirsin.');
      }
      setState(() { _yukleniyor = true; _hata = null; });
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      var locationName = 'Konumum';
      try {
        final places = await Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
        if (places.isNotEmpty) {
          final place = places.first;
          locationName = <String?>[place.subAdministrativeArea, place.administrativeArea]
              .where((part) => part != null && part.trim().isNotEmpty)
              .map((part) => part!.trim())
              .toSet()
              .join(', ');
          if (locationName.isEmpty) locationName = place.locality?.trim() ?? 'Konumum';
        }
      } catch (_) {}
      _arama.text = locationName;
      await _koordinattanGetir(position.latitude, position.longitude, locationName);
    } catch (error) {
      if (mounted) setState(() => _hata = error.toString().replaceFirst('Exception: ', ''));
      if (_hava == null) await _sehriGetir();
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _koordinattanGetir(double lat, double lon, String name) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/weather').replace(
      queryParameters: {'lat': '$lat', 'lon': '$lon', 'name': name},
    );
    final response = await ApiClient.get(uri);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 || decoded is! Map) throw Exception('Konumun hava verisi alınamadı.');
    if (mounted) setState(() => _hava = Map<String, dynamic>.from(decoded));
    await _havaKartiKaydet(Map<String, dynamic>.from(decoded));
    if (_bildirimlerAcik) await _bildirimTercihiniDegistir(true, sessiz: true);
  }

  Future<void> _havaKartiKaydet(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final location = data['location'] is Map ? data['location'] as Map : const {};
    final current = data['current'] is Map ? data['current'] as Map : const {};
    await prefs.setString('weather_card_location', '${location['name'] ?? 'Konumum'}');
    await prefs.setString('weather_card_description', '${current['description'] ?? ''}');
    if (current['weatherCode'] is num) await prefs.setInt('weather_card_code', (current['weatherCode'] as num).toInt());
    if (current['temperature'] is num) await prefs.setDouble('weather_card_temperature', (current['temperature'] as num).toDouble());
    if (location['latitude'] is num) await prefs.setDouble('weather_card_latitude', (location['latitude'] as num).toDouble());
    if (location['longitude'] is num) await prefs.setDouble('weather_card_longitude', (location['longitude'] as num).toDouble());
  }

  Future<void> _bildirimTercihiniDegistir(bool enabled, {bool sessiz = false}) async {
    if (!enabled) {
      await WeatherNotificationService.disable();
      if (mounted) setState(() => _bildirimlerAcik = false);
      return;
    }
    final location = Map<String, dynamic>.from(_hava?['location'] as Map? ?? {});
    final lat = location['latitude'];
    final lon = location['longitude'];
    if (lat is! num || lon is! num) {
      if (!sessiz) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce konum veya şehir hava verisini yükle.')));
      return;
    }
    final warnings = _list('warnings');
    final allowed = await WeatherNotificationService.enable(
      latitude: lat.toDouble(), longitude: lon.toDouble(),
      locationName: '${location['name'] ?? 'Konumum'}',
      currentCode: _current['weatherCode'] is num ? (_current['weatherCode'] as num).toInt() : null,
      warning: warnings.isEmpty ? '' : '${warnings.first['message'] ?? ''}',
    );
    if (mounted) setState(() => _bildirimlerAcik = allowed);
    if (!allowed && !sessiz && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim izni verilmedi.')));
    }
  }

  Map<String, dynamic> get _current => Map<String, dynamic>.from(_hava?['current'] as Map? ?? {});
  List<Map<String, dynamic>> _list(String key) => (_hava?[key] as List? ?? const [])
      .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  String _num(dynamic value, [int fraction = 0]) => value is num ? value.toStringAsFixed(fraction) : '-';

  IconData _icon(dynamic code) {
    final c = code is num ? code.toInt() : -1;
    if ([0, 1].contains(c)) return Icons.wb_sunny_rounded;
    if ([2, 3, 45, 48].contains(c)) return Icons.cloud_rounded;
    if (c >= 71 && c <= 86) return Icons.ac_unit_rounded;
    if (c >= 95) return Icons.thunderstorm_rounded;
    return Icons.water_drop_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050C16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071421),
        title: const Text('Akıllı Hava Merkezi'),
        actions: [
          IconButton(tooltip: 'Konumumu bul', onPressed: _yukleniyor ? null : _konumuBul, icon: const Icon(Icons.my_location_rounded)),
          IconButton(onPressed: _yukleniyor ? null : _sehriGetir, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _sehriGetir,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          children: [
            TextField(
              controller: _arama,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _sehriGetir(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Şehir veya ilçe ara',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(onPressed: _sehriGetir, icon: const Icon(Icons.search_rounded)),
              ),
            ),
            if (_yukleniyor) ...[
              const SizedBox(height: 22),
              const LinearProgressIndicator(),
            ],
            if (_hata != null) ...[
              const SizedBox(height: 16),
              _panel(child: Text(_hata!, style: const TextStyle(color: Color(0xFFFF8A92)))),
            ],
            if (_hava != null) ...[
              const SizedBox(height: 16),
              _anaKart(),
              const SizedBox(height: 10),
              _panel(child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _bildirimlerAcik,
                onChanged: _bildirimTercihiniDegistir,
                secondary: Icon(_bildirimlerAcik ? Icons.notifications_active_rounded : Icons.notifications_off_outlined, color: const Color(0xFF7DD3FC)),
                title: const Text('Hava değişikliği bildirimleri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                subtitle: const Text('İsteğe bağlıdır. Önemli değişim veya risk oluşunca bildirir.', style: TextStyle(color: Color(0xFF8097A9), fontSize: 11)),
              )),
              if (_list('warnings').isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._list('warnings').map(_uyari),
              ],
              const SizedBox(height: 18),
              _baslik('Önümüzdeki 24 Saat', Icons.schedule_rounded),
              const SizedBox(height: 10),
              _saatlik(),
              const SizedBox(height: 20),
              _baslik('8 Günlük Tahmin', Icons.calendar_month_rounded),
              const SizedBox(height: 10),
              ..._list('daily').map(_gunluk),
              const SizedBox(height: 14),
              const Text('Kaynak: Open‑Meteo • Veriler 15 dakika önbelleğe alınır.', style: TextStyle(color: Color(0xFF71879A), fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _anaKart() {
    final location = Map<String, dynamic>.from(_hava?['location'] as Map? ?? {});
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF123D59), Color(0xFF0B2135)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2D6B8D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${location['name'] ?? _arama.text}', style: const TextStyle(color: Color(0xFFB9E8FF), fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Row(children: [
          Icon(_icon(_current['weatherCode']), size: 58, color: const Color(0xFFFFD166)),
          const SizedBox(width: 14),
          Text('${_num(_current['temperature'])}°', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          Expanded(child: Text('${_current['description'] ?? '-'}\nHissedilen ${_num(_current['apparentTemperature'])}°', style: const TextStyle(color: Color(0xFFD3E7F4), height: 1.5))),
        ]),
        const Divider(color: Color(0xFF2B536B), height: 28),
        Wrap(spacing: 14, runSpacing: 12, children: [
          _metric(Icons.water_drop_outlined, 'Nem', '%${_num(_current['humidity'])}'),
          _metric(Icons.air_rounded, 'Rüzgâr', '${_num(_current['windSpeed'])} km/s'),
          _metric(Icons.speed_rounded, 'Basınç', '${_num(_current['pressure'])} hPa'),
          _metric(Icons.cloud_outlined, 'Bulut', '%${_num(_current['cloudCover'])}'),
        ]),
      ]),
    );
  }

  Widget _saatlik() => SizedBox(
    height: 132,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _list('hourly').length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final h = _list('hourly')[i];
        final time = DateTime.tryParse('${h['time']}');
        return _panel(width: 84, child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(time == null ? '-' : '${time.hour.toString().padLeft(2, '0')}:00', style: const TextStyle(color: Color(0xFFAFC4D3))),
          Icon(_icon(h['weatherCode']), color: const Color(0xFF7DD3FC)),
          Text('${_num(h['temperature'])}°', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          Text('%${_num(h['precipitationProbability'])} yağış', style: const TextStyle(color: Color(0xFF7D99AE), fontSize: 9)),
        ]));
      },
    ),
  );

  Widget _gunluk(Map<String, dynamic> day) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _panel(child: Row(children: [
      Icon(_icon(day['weatherCode']), color: const Color(0xFF7DD3FC)),
      const SizedBox(width: 12),
      Expanded(child: Text('${day['date']}\n${day['description'] ?? '-'}', style: const TextStyle(color: Colors.white, height: 1.35))),
      Text('${_num(day['minTemperature'])}°  /  ${_num(day['maxTemperature'])}°', style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.w900)),
      const SizedBox(width: 10),
      Text('%${_num(day['precipitationProbability'])}', style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 11)),
    ])),
  );

  Widget _uyari(Map<String, dynamic> warning) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF3A2414), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF8A5A24))),
      child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC857)), const SizedBox(width: 9), Expanded(child: Text('${warning['message']}', style: const TextStyle(color: Color(0xFFFFDDA0))))]),
    ),
  );

  Widget _metric(IconData icon, String title, String value) => SizedBox(width: 135, child: Row(children: [Icon(icon, size: 18, color: const Color(0xFF7DD3FC)), const SizedBox(width: 7), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF829BAD), fontSize: 10)), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))])])) ;
  Widget _baslik(String text, IconData icon) => Row(children: [Icon(icon, color: const Color(0xFF6EE7F9)), const SizedBox(width: 8), Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))]);
  Widget _panel({required Widget child, double? width}) => Container(width: width, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0A1927), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF1B3B52))), child: child);
}
