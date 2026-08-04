import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/premium_sayfasi.dart';
import 'ayarlar_sayfasi.dart';
import 'dunya_tarama_sayfasi.dart';
import 'firsatlar_sayfasi.dart';
import 'haberler_sayfasi.dart';
import 'hava_merkezi_sayfasi.dart';
import 'daily_digest_navigation.dart';
import 'theme/trendora_theme.dart';
import 'trend_tahmini_sayfasi.dart';
import 'core/weather_notification_service.dart';
import 'core/auth/trendora_auth_service.dart';
import 'core/api_client.dart';
import 'core/api_config.dart';
import 'core/daily_digest/daily_digest_models.dart';
import 'widgets/daily_digest_section.dart';
import 'widgets/personalized_recommendations_section.dart';
import 'widgets/smart_shortcuts_section.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TrendoraAuthService.instance.initialize();
  await WeatherNotificationService.initialize(
    onNotificationPayload: _handleSmartNotificationPayload,
  );
  runApp(const TrendoraApp());
}

final GlobalKey<NavigatorState> trendoraNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> _handleSmartNotificationPayload(String? raw) async {
  if (raw == null || raw.trim().isEmpty) return;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final data = Map<String, dynamic>.from(decoded);
    final context = trendoraNavigatorKey.currentContext;
    if (context == null) return;
    if (data['type'] == 'dailyDigest') {
      trendoraNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    final type = '${data['type'] ?? ''}';
    final category = switch (type) {
      'news' => DailyDigestCategory.news,
      'opportunity' => DailyDigestCategory.opportunities,
      'weather' => DailyDigestCategory.weather,
      'analysis' => DailyDigestCategory.savedAnalyses,
      _ => DailyDigestCategory.finance,
    };
    final item = DailyDigestItem(
      id: 'notification:${data['itemId'] ?? data['canonicalSymbol'] ?? type}',
      category: category,
      title: '${data['title'] ?? ''}',
      detail: '${data['detail'] ?? ''}',
      source: '${data['source'] ?? 'Trendora'}',
      updatedAt:
          DateTime.tryParse('${data['updatedAt'] ?? ''}') ?? DateTime.now(),
      reference: '${data['canonicalSymbol'] ?? data['itemId'] ?? ''}',
      itemType: type,
      itemId: '${data['itemId'] ?? ''}'.trim().isEmpty
          ? null
          : '${data['itemId']}',
      canonicalSymbol: '${data['canonicalSymbol'] ?? ''}'.trim().isEmpty
          ? null
          : '${data['canonicalSymbol']}',
      originalUrl: '${data['originalUrl'] ?? ''}'.trim().isEmpty
          ? null
          : '${data['originalUrl']}',
      snapshot: data['snapshot'] is Map
          ? Map<String, dynamic>.from(data['snapshot'] as Map)
          : null,
      target: '${data['target'] ?? ''}',
      targetArguments: data['targetArguments'] is Map
          ? Map<String, dynamic>.from(data['targetArguments'] as Map)
          : null,
      currentStatus: '${data['currentStatus'] ?? ''}',
    );
    final opened = await openDailyDigestItem(context, item);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bildirim ayrıntısı artık kullanılamıyor.'),
        ),
      );
    }
  } catch (_) {
    // Bozuk veya eski payload uygulamayı durdurmaz.
  }
}

class TrendoraApp extends StatelessWidget {
  const TrendoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: trendoraNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Trendora',
      theme: TrendoraTheme.dark,
      builder: (context, child) => ColoredBox(
        color: const Color(0xFF030812),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      home: const AcilisSayfasi(),
    );
  }
}

class AcilisSayfasi extends StatelessWidget {
  const AcilisSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _PremiumArkaPlan()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _MarkaRozeti(),
                  ),
                  const Spacer(),
                  const _AcilisHero(),
                  const Spacer(),
                  _CanliDurumSatiri(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DunyaTaramaSayfasi(
                              sonrakiSayfa: AnaMenu(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.radar_rounded),
                      label: const Text('DÜNYAYI TARAMAYA BAŞLA'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Haberler, fırsatlar ve yükselen eğilimler tek merkezde.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TrendoraColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnaMenu extends StatelessWidget {
  const AnaMenu({super.key});

  void _sayfayaGit(BuildContext context, Widget sayfa) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => sayfa,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Animation<double> fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          final Animation<Offset> slide = Tween<Offset>(
            begin: const Offset(0.035, 0.025),
            end: Offset.zero,
          ).animate(fade);

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size ekran = MediaQuery.sizeOf(context);
    final bool darEkran = ekran.width < 370;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _PremiumArkaPlan(sade: true)),
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _AnaMenuArkaPlanPainter()),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        darEkran ? 15 : 19,
                        10,
                        darEkran ? 15 : 19,
                        8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _PremiumUstBar(
                          onAyarlar: () {
                            _sayfayaGit(context, const AyarlarSayfasi());
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        darEkran ? 15 : 19,
                        10,
                        darEkran ? 15 : 19,
                        0,
                      ),
                      sliver: const SliverToBoxAdapter(child: _AnaMenuHero()),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        darEkran ? 15 : 19,
                        18,
                        darEkran ? 15 : 19,
                        0,
                      ),
                      sliver: const SliverToBoxAdapter(
                        child: _BolumBasligi(
                          baslik: 'KEŞFET',
                          aciklama: 'Trendora merkezlerinden birini seç',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        darEkran ? 15 : 19,
                        11,
                        darEkran ? 15 : 19,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _PremiumAnaKart(
                          etiket: 'TRENDORA ANALİZ MOTORU',
                          baslik: 'Trend Analiz Merkezi',
                          aciklama:
                              'Yükselen eğilimleri, teknik göstergeleri ve kaynak destekli analizleri tek merkezde incele.',
                          icon: Icons.auto_graph_rounded,
                          accent: TrendoraColors.primary,
                          ikincilRenk: TrendoraColors.secondary,
                          bilgi: 'Canlı analiz',
                          onTap: () {
                            _sayfayaGit(context, const TrendTahminiSayfasi());
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        darEkran ? 15 : 19,
                        12,
                        darEkran ? 15 : 19,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: _PremiumKucukKart(
                                baslik: 'Haber\nMerkezi',
                                aciklama: 'Gündemi anlık takip et',
                                icon: Icons.newspaper_rounded,
                                accent: TrendoraColors.secondary,
                                onTap: () {
                                  _sayfayaGit(context, const HaberlerSayfasi());
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PremiumKucukKart(
                                baslik: 'Fırsatlar\nMerkezi',
                                aciklama: 'İndirimleri keşfet',
                                icon: Icons.local_offer_rounded,
                                accent: TrendoraColors.success,
                                onTap: () {
                                  _sayfayaGit(
                                    context,
                                    const FirsatlarSayfasi(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        darEkran ? 15 : 19,
                        18,
                        darEkran ? 15 : 19,
                        0,
                      ),
                      sliver: const SliverToBoxAdapter(
                        child: _BolumBasligi(
                          baslik: 'TRENDORA',
                          aciklama: 'Hesap ve uygulama seçenekleri',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        darEkran ? 15 : 19,
                        11,
                        darEkran ? 15 : 19,
                        28,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _PremiumYatayKart(
                              baslik: 'Premium',
                              aciklama: 'Gelişmiş özellikler yakında',
                              icon: Icons.workspace_premium_rounded,
                              accent: TrendoraColors.accent,
                              kilitli: true,
                              onTap: () {
                                _sayfayaGit(context, const PremiumSayfasi());
                              },
                            ),
                            const SizedBox(height: 10),
                            _PremiumYatayKart(
                              baslik: 'Akıllı Hava Merkezi',
                              aciklama:
                                  'Otomatik konum, saatlik tahmin ve isteğe bağlı bildirimler',
                              icon: Icons.cloud_outlined,
                              accent: const Color(0xFF6EE7F9),
                              onTap: () => _sayfayaGit(
                                context,
                                const HavaMerkeziSayfasi(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF050C16),
              child: _SabitAnaMenuIcerigi(
                onAyarlar: () => _sayfayaGit(context, const AyarlarSayfasi()),
                onTrend: () =>
                    _sayfayaGit(context, const TrendTahminiSayfasi()),
                onHaberler: () => _sayfayaGit(context, const HaberlerSayfasi()),
                onFirsatlar: () =>
                    _sayfayaGit(context, const FirsatlarSayfasi()),
                onPremium: () => _sayfayaGit(context, const PremiumSayfasi()),
                onHava: () => _sayfayaGit(context, const HavaMerkeziSayfasi()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SabitAnaMenuIcerigi extends StatelessWidget {
  final VoidCallback onAyarlar;
  final VoidCallback onTrend;
  final VoidCallback onHaberler;
  final VoidCallback onFirsatlar;
  final VoidCallback onPremium;
  final VoidCallback onHava;

  const _SabitAnaMenuIcerigi({
    required this.onAyarlar,
    required this.onTrend,
    required this.onHaberler,
    required this.onFirsatlar,
    required this.onPremium,
    required this.onHava,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: 410,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PremiumUstBar(onAyarlar: onAyarlar),
                    const SizedBox(height: 12),
                    const _AnaMenuHero(),
                    const SizedBox(height: 16),
                    PersonalizedRecommendationsSection(
                      onOpenNews: onHaberler,
                      onOpenOpportunities: onFirsatlar,
                      onOpenFinance: (symbol) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TrendTahminiSayfasi(
                              initialQuery:
                                  '$symbol güncel durumu ve olasılık analizi',
                              autoAnalyze: true,
                            ),
                          ),
                        );
                      },
                    ),
                    DailyDigestSection(
                      onOpenNews: onHaberler,
                      onOpenOpportunities: onFirsatlar,
                      onOpenWeather: onHava,
                      onOpenDirectItem: (item) =>
                          openDailyDigestItem(context, item),
                      onNotificationPayload: _handleSmartNotificationPayload,
                      onOpenFinance: (query) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TrendTahminiSayfasi(
                              initialQuery:
                                  '$query güncel durumu ve olasılık analizi',
                              autoAnalyze: true,
                            ),
                          ),
                        );
                      },
                    ),
                    const SmartShortcutsSection(),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _BolumBasligi(
                        baslik: 'KEŞFET',
                        aciklama: 'Trendora merkezlerinden birini seç',
                      ),
                    ),
                    const SizedBox(height: 9),
                    _CanliTrendKart(onFallback: onTrend),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _CanliHaberKart(onTap: onHaberler)),
                        const SizedBox(width: 10),
                        Expanded(child: _CanliFirsatKart(onTap: onFirsatlar)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PremiumYatayKart(
                      baslik: 'Premium',
                      aciklama: 'Gelişmiş özellikler yakında',
                      icon: Icons.workspace_premium_rounded,
                      accent: TrendoraColors.accent,
                      kilitli: true,
                      onTap: onPremium,
                    ),
                    const SizedBox(height: 10),
                    _CanliHavaKart(onTap: onHava),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanliTrendKart extends StatefulWidget {
  final VoidCallback onFallback;
  const _CanliTrendKart({required this.onFallback});

  @override
  State<_CanliTrendKart> createState() => _CanliTrendKartState();
}

class _CanliTrendKartState extends State<_CanliTrendKart> {
  List<Map<String, dynamic>> _items = const [];
  Timer? _ticker;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted && _items.length > 1) {
        setState(() => _index = (_index + 1) % _items.length);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool _isBistStock(Map<String, dynamic> asset) {
    final symbol = '${asset['canonicalSymbol'] ?? asset['symbol'] ?? ''}'
        .toUpperCase();
    final exchange = '${asset['exchange'] ?? ''}'.toUpperCase();
    final type = '${asset['assetType'] ?? asset['subtype'] ?? ''}'
        .toLowerCase();
    return symbol.endsWith('.IS') ||
        exchange == 'BIST' ||
        type.contains('hisse') ||
        type.contains('stock') ||
        type.contains('equity');
  }

  Future<void> _load() async {
    final merged = <String, Map<String, dynamic>>{};

    String itemKey(Map<String, dynamic> item) {
      final symbol = '${item['symbol'] ?? ''}'.trim().toUpperCase();
      if (symbol.isNotEmpty) return symbol;
      return '${item['label'] ?? ''}'.trim().toUpperCase();
    }

    double? number(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(
          value.replaceAll(',', '.').replaceAll('%', '').trim(),
        );
      }
      return null;
    }

    void addItem(Map<String, dynamic> item, {bool overwrite = false}) {
      final key = itemKey(item);
      if (key.isEmpty) return;
      if (overwrite || !merged.containsKey(key)) {
        merged[key] = item;
      }
    }

    // 1) Trendora'nın otomatik piyasa taramasındaki bütün canlı varlıkları al.
    // Böylece akış tek bir prediction-memory kaydına bağlı kalmaz.
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/trends/market-board'),
        timeout: const Duration(seconds: 30),
        cacheTtl: const Duration(minutes: 2),
      );
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final raw = body is Map ? body['items'] : null;

      if (response.statusCode == 200 && raw is List) {
        for (final entry in raw.whereType<Map>()) {
          final market = Map<String, dynamic>.from(entry);
          final label =
              '${market['label'] ?? market['displayName'] ?? market['name'] ?? market['symbol'] ?? ''}'
                  .trim();
          final symbol =
              '${market['canonicalSymbol'] ?? market['symbol'] ?? ''}'.trim();
          final price = number(
            market['price'] ??
                market['currentPrice'] ??
                market['lastPrice'] ??
                market['close'],
          );

          if (label.isEmpty || price == null || price <= 0) continue;

          final change = number(
            market['changePercent'] ??
                market['dailyChangePercent'] ??
                market['change'],
          );

          final rawScore = number(
            market['technicalScore'] ??
                market['trendScore'] ??
                market['score'] ??
                market['confidence'],
          );

          final score = rawScore == null
              ? change == null
                    ? 50
                    : (50 + change.clamp(-10.0, 10.0) * 3).round().clamp(0, 100)
              : rawScore.round().clamp(0, 100);

          final rawDirection = '${market['direction'] ?? market['trend'] ?? ''}'
              .toLowerCase();
          final direction = rawDirection.isNotEmpty
              ? rawDirection
              : change == null
              ? 'stable'
              : change > 0
              ? 'rising'
              : change < 0
              ? 'falling'
              : 'stable';

          final history = <double>[];
          final rawHistory =
              market['history'] ?? market['prices'] ?? market['sparkline'];
          if (rawHistory is List) {
            for (final value in rawHistory) {
              final parsed = number(
                value is Map
                    ? (value['close'] ?? value['price'] ?? value['value'])
                    : value,
              );
              if (parsed != null && parsed > 0) history.add(parsed);
            }
          }

          addItem({
            'predictionId': 'market-$symbol',
            'label': label,
            'symbol': symbol,
            'query': '$label güncel durumu ve olasılık analizi',
            'price': price,
            'currency': market['currency'],
            'technicalScore': score,
            'direction': direction,
            'rsi14': market['rsi14'] ?? market['rsi'],
            'atrPercent': market['atrPercent'] ?? market['atr'],
            'confidence': market['confidence'] ?? score,
            'changePercent': change,
            'createdAt': market['updatedAt'] ?? market['createdAt'],
            'history': history,
          });
        }
      }
    } catch (_) {
      // Prediction kayıtları yine de yüklenmeye çalışılır.
    }

    // 2) Kayıtlı gerçek Trendora öngörülerini ekle.
    // Aynı varlık varsa ayrıntılı prediction kaydı canlı piyasa kartının üzerine yazılır.
    try {
      final response = await ApiClient.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/trends/predictions?status=all&limit=30',
        ),
        timeout: const Duration(seconds: 20),
      );
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final raw = body is Map ? body['items'] : null;

      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          final predictionRecord = Map<String, dynamic>.from(entry);
          final assetRaw = predictionRecord['asset'];
          final predictionRaw = predictionRecord['prediction'];
          final technicalRaw = predictionRecord['technicalSnapshot'];
          if (assetRaw is! Map || predictionRaw is! Map) continue;

          final asset = Map<String, dynamic>.from(assetRaw);
          final prediction = Map<String, dynamic>.from(predictionRaw);
          final technical = technicalRaw is Map
              ? Map<String, dynamic>.from(technicalRaw)
              : <String, dynamic>{};

          final label =
              '${asset['displayName'] ?? asset['name'] ?? asset['canonicalSymbol'] ?? asset['symbol'] ?? ''}'
                  .trim();
          final currentPrice = number(prediction['currentPrice']);
          if (label.isEmpty || currentPrice == null || currentPrice <= 0) {
            continue;
          }

          final history = <double>[];
          for (final value in [
            prediction['estimatedLow'],
            prediction['estimatedMid'],
            prediction['estimatedHigh'],
            prediction['currentPrice'],
          ]) {
            final parsed = number(value);
            if (parsed != null && parsed > 0) history.add(parsed);
          }

          addItem({
            'predictionId': predictionRecord['id'],
            'label': label,
            'symbol': asset['canonicalSymbol'] ?? asset['symbol'],
            'query': predictionRecord['query'] ?? label,
            'price': currentPrice,
            'currency': prediction['currency'] ?? asset['currency'],
            'technicalScore':
                technical['score'] ?? prediction['confidence'] ?? 50,
            'direction': prediction['direction'] ?? 'stable',
            'rsi14': technical['rsi14'],
            'atrPercent': technical['atrPercent'],
            'confidence': prediction['confidence'],
            'horizonDays': predictionRecord['horizonDays'],
            'createdAt': predictionRecord['createdAt'],
            'history': history,
          }, overwrite: true);
        }
      }
    } catch (_) {
      // Market-board kayıtları varsa akış çalışmaya devam eder.
    }

    if (!mounted) return;

    final items = merged.values.toList();
    if (items.isNotEmpty) {
      setState(() {
        _items = items;
        _index = 0;
      });
    }
  }

  void _openAnalysis(Map<String, dynamic> item) {
    final label = '${item['label']}';
    final query = '${item['query'] ?? ''}'.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrendTahminiSayfasi(
          initialQuery: query.isNotEmpty ? query : '$label analizi',
          autoAnalyze: true,
        ),
      ),
    );
  }

  void _openStatistics(Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _OngoruIstatistikSayfasi(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return _PremiumAnaKart(
        etiket: 'TRENDORA ANALİZ MOTORU',
        baslik: 'Trend Analiz Merkezi',
        aciklama: 'Trendora tahminleri hazırlanıyor.',
        icon: Icons.auto_graph_rounded,
        accent: TrendoraColors.primary,
        ikincilRenk: TrendoraColors.secondary,
        bilgi: 'Canlı analiz',
        onTap: widget.onFallback,
      );
    }

    final item = _items[_index];
    final score = item['technicalScore'] is num
        ? (item['technicalScore'] as num).round()
        : 50;
    final direction = '${item['direction']}'.toLowerCase();
    final rising = direction == 'rising' || score >= 55;
    final falling = direction == 'falling' || score <= 43;
    final neutral = !rising && !falling;
    final color = neutral
        ? const Color(0xFFFFC857)
        : rising
        ? const Color(0xFF55E6A5)
        : const Color(0xFFFF7580);
    final history = (item['history'] as List? ?? const [])
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList();
    final label = '${item['label']}';
    final currency = '${item['currency'] ?? ''}'.trim();

    return GestureDetector(
      onTap: () => _openAnalysis(item),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 650),
        child: Container(
          key: ValueKey('${item['predictionId']}-$label'),
          height: 185,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF152C48), Color(0xFF081522)],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color.withValues(alpha: .45)),
          ),
          child: Stack(
            children: [
              if (history.length >= 2)
                Positioned.fill(
                  child: Opacity(
                    opacity: .24,
                    child: CustomPaint(
                      painter: _MiniTrendPainter(history, color),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.analytics_rounded,
                        color: Color(0xFF7DD3FC),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TRENDORA ÖNGÖRÜ AKIŞI',
                        style: TextStyle(
                          color: Color(0xFFBCEBFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$score/100',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '$label • ${neutral
                        ? 'YATAY/BEKLE'
                        : rising
                        ? 'YÜKSELİŞ EĞİLİMİ'
                        : 'DÜŞÜŞ RİSKİ'}',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Tahmin fiyatı ${item['price']}${currency.isEmpty ? '' : ' $currency'} • RSI ${item['rsi14'] is num ? (item['rsi14'] as num).toStringAsFixed(1) : '-'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'VARLIĞI ANALİZ ET',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openStatistics(item),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 2,
                          ),
                          child: Text(
                            'İSTATİSTİKLERİ AÇ  →',
                            style: TextStyle(
                              color: Color(0xFF7DD3FC),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OngoruIstatistikSayfasi extends StatefulWidget {
  final Map<String, dynamic> item;
  const _OngoruIstatistikSayfasi({required this.item});

  @override
  State<_OngoruIstatistikSayfasi> createState() =>
      _OngoruIstatistikSayfasiState();
}

class _OngoruIstatistikSayfasiState extends State<_OngoruIstatistikSayfasi> {
  String _period = '1A';
  bool _saved = false;
  bool _chartLoading = true;
  String? _chartError;
  List<Map<String, dynamic>> _candles = const [];
  double? _support;
  double? _resistance;

  Map<String, dynamic> get item => widget.item;

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  String get _chartRange => switch (_period) {
    '1H' => '1w',
    '1A' => '1m',
    '3A' => '3m',
    _ => '1m',
  };

  String get _chartQuery {
    final symbol = '${item['symbol'] ?? ''}'.trim();
    if (symbol.isNotEmpty) return symbol;
    final query = '${item['query'] ?? ''}'.trim();
    if (query.isNotEmpty) return query;
    return '${item['label']}';
  }

  double? _positiveNumber(dynamic value) {
    if (value is! num) return null;
    final result = value.toDouble();
    return result.isFinite && result > 0 ? result : null;
  }

  void _calculateLevels(List<Map<String, dynamic>> candles) {
    final lows = candles
        .map(
          (row) => _positiveNumber(row['low']) ?? _positiveNumber(row['close']),
        )
        .whereType<double>()
        .toList();
    final highs = candles
        .map(
          (row) =>
              _positiveNumber(row['high']) ?? _positiveNumber(row['close']),
        )
        .whereType<double>()
        .toList();
    if (lows.isEmpty || highs.isEmpty) {
      _support = null;
      _resistance = null;
      return;
    }
    _support = lows.reduce(math.min);
    _resistance = highs.reduce(math.max);
    if (_support == _resistance) {
      _support = null;
      _resistance = null;
    }
  }

  Future<void> _loadChart() async {
    setState(() {
      _chartLoading = true;
      _chartError = null;
    });
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/trends/chart',
      ).replace(queryParameters: {'query': _chartQuery, 'range': _chartRange});
      final response = await ApiClient.get(
        uri,
        timeout: const Duration(seconds: 35),
      );
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final raw = body is Map ? body['candles'] : null;
      if (raw is! List)
        throw const FormatException('Grafik verisi bulunamadı.');
      final candles = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((row) {
            return _positiveNumber(row['close']) != null &&
                _positiveNumber(row['high']) != null &&
                _positiveNumber(row['low']) != null;
          })
          .toList();
      if (candles.isEmpty)
        throw const FormatException('Grafik verisi bulunamadı.');
      _calculateLevels(candles);
      if (!mounted) return;
      setState(() {
        _candles = candles;
        _chartLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _candles = const [];
        _support = null;
        _resistance = null;
        _chartLoading = false;
        _chartError =
            'Bu dönem için yeterli doğrulanmış piyasa verisi bulunamadı.';
      });
    }
  }

  String _formatLevel(double? value) {
    if (value == null || !value.isFinite || value <= 0) return '—';
    return value.toStringAsFixed(value < 100 ? 2 : 1);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('saved_market_forecasts') ?? <String>[];
    final record = jsonEncode({
      'symbol': item['label'],
      'price': item['price'],
      'score': item['technicalScore'],
      'direction': item['direction'],
      'savedAt': DateTime.now().toIso8601String(),
    });
    current.removeWhere((raw) {
      try {
        return jsonDecode(raw)['symbol'] == item['label'];
      } catch (_) {
        return false;
      }
    });
    current.insert(0, record);
    await prefs.setStringList(
      'saved_market_forecasts',
      current.take(50).toList(),
    );
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final score = item['technicalScore'] is num
        ? (item['technicalScore'] as num).round()
        : 50;
    final color = score >= 55
        ? const Color(0xFF55E6A5)
        : score <= 43
        ? const Color(0xFFFF7580)
        : const Color(0xFFFFC857);
    final label = '${item['label']}';
    final savedQuery = '${item['query'] ?? ''}'.trim();
    final analysisQuery = savedQuery.isNotEmpty
        ? savedQuery
        : '$label önümüzdeki 1 ay ne olur?';
    Widget stat(String title, dynamic value) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1B2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF1C4059)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF829BAD), fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF050C16),
      appBar: AppBar(title: Text('$label İstatistikleri')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: ['1H', '1A', '3A']
                .map(
                  (period) => ChoiceChip(
                    label: Text(period),
                    selected: _period == period,
                    onSelected: (_) {
                      if (_period == period) return;
                      setState(() => _period = period);
                      _loadChart();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Container(
            height: 300,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF081725),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child: _chartLoading
                ? const Center(child: CircularProgressIndicator())
                : _candles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _chartError ?? 'Grafik verisi bulunamadı.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF91A8B8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: _MumOngoruPainter(
                      candles: _candles,
                      color: color,
                      support: _support,
                      resistance: _resistance,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Doğrulanmış OHLC mumları • Dönem desteği/direnci • Fibonacci seviyeleri',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7892A5), fontSize: 10.5),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              stat('Teknik skor', '$score/100'),
              stat('Tahmin fiyatı', item['price']),
              stat(
                'RSI (14)',
                item['rsi14'] is num
                    ? (item['rsi14'] as num).toStringAsFixed(1)
                    : '—',
              ),
              stat(
                'ATR oynaklığı',
                item['atrPercent'] is num
                    ? '%${(item['atrPercent'] as num).toStringAsFixed(2)}'
                    : '—',
              ),
              stat('Destek', _formatLevel(_support)),
              stat('Direnç', _formatLevel(_resistance)),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrendTahminiSayfasi(
                  initialQuery: analysisQuery,
                  autoAnalyze: true,
                ),
              ),
            ),
            icon: const Icon(Icons.auto_graph_rounded),
            label: const Text('ANALİZİ AÇ'),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: _save,
            icon: Icon(
              _saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
            ),
            label: Text(_saved ? 'KAYDEDİLDİ' : 'ÖNGÖRÜYÜ KAYDET'),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrendTahminiSayfasi()),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('BAŞKA HİSSE SOR'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Bu öngörü teknik olasılık değerlendirmesidir; kesin getiri veya yatırım tavsiyesi değildir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7F93A5), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MumOngoruPainter extends CustomPainter {
  final List<Map<String, dynamic>> candles;
  final Color color;
  final num? support;
  final num? resistance;
  const _MumOngoruPainter({
    required this.candles,
    required this.color,
    this.support,
    this.resistance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    double? value(Map<String, dynamic> row, String key) {
      final raw = row[key];
      if (raw is! num) return null;
      final result = raw.toDouble();
      return result.isFinite && result > 0 ? result : null;
    }

    final lows = candles
        .map((e) => value(e, 'low') ?? value(e, 'close'))
        .whereType<double>()
        .toList();
    final highs = candles
        .map((e) => value(e, 'high') ?? value(e, 'close'))
        .whereType<double>()
        .toList();
    if (lows.isEmpty || highs.isEmpty) return;

    final rawMin = lows.reduce(math.min);
    final rawMax = highs.reduce(math.max);
    final rawRange = rawMax - rawMin;
    final padding = rawRange.abs() < .0001
        ? math.max(rawMax.abs() * .01, .01)
        : rawRange * .06;
    final minPrice = math.max(0.0, rawMin - padding);
    final maxPrice = rawMax + padding;
    final range = math.max(maxPrice - minPrice, .0001);
    final area = Rect.fromLTRB(8, 12, size.width - 48, size.height - 18);
    double y(double price) =>
        area.bottom -
        ((price - minPrice) / range).clamp(0.0, 1.0) * area.height;

    final grid = Paint()
      ..color = const Color(0xFF1C3447)
      ..strokeWidth = .7;
    for (var i = 0; i <= 4; i++) {
      final yy = area.top + area.height * i / 4;
      canvas.drawLine(Offset(area.left, yy), Offset(area.right, yy), grid);
      final price = maxPrice - range * i / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: price.toStringAsFixed(price < 100 ? 2 : 1),
          style: const TextStyle(color: Color(0xFF7790A3), fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(area.right + 4, yy - 5));
    }

    final step = area.width / candles.length;
    final bodyWidth = (step * .58).clamp(2.0, 10.0);
    for (var i = 0; i < candles.length; i++) {
      final row = candles[i];
      final close = value(row, 'close');
      final open = value(row, 'open') ?? close;
      final high = value(row, 'high') ?? close;
      final low = value(row, 'low') ?? close;
      if (close == null || open == null || high == null || low == null)
        continue;
      final x = area.left + step * (i + .5);
      final up = close >= open;
      final paint = Paint()
        ..color = up ? const Color(0xFF52D99A) : const Color(0xFFFF6F7D)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, y(high)), Offset(x, y(low)), paint);
      final bodyTop = math.min(y(open), y(close));
      final bodyBottom = math.max(y(open), y(close));
      canvas.drawRect(
        Rect.fromLTRB(
          x - bodyWidth / 2,
          bodyTop,
          x + bodyWidth / 2,
          math.max(bodyBottom, bodyTop + 1),
        ),
        paint,
      );
    }

    void level(num? raw, Color levelColor) {
      if (raw == null) return;
      final levelValue = raw.toDouble();
      if (!levelValue.isFinite ||
          levelValue <= 0 ||
          levelValue < minPrice ||
          levelValue > maxPrice)
        return;
      final yy = y(levelValue);
      canvas.drawLine(
        Offset(area.left, yy),
        Offset(area.right, yy),
        Paint()
          ..color = levelColor
          ..strokeWidth = 1.1,
      );
    }

    level(support, const Color(0xFF38BDF8));
    level(resistance, const Color(0xFFFFC857));
    for (final ratio in [.236, .382, .5, .618, .786]) {
      final yy = y(rawMin + rawRange * ratio);
      canvas.drawLine(
        Offset(area.left, yy),
        Offset(area.right, yy),
        Paint()
          ..color = const Color(0x555E7CE2)
          ..strokeWidth = .65,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MumOngoruPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.support != support ||
        oldDelegate.resistance != resistance ||
        oldDelegate.color != color;
  }
}

class _MiniTrendPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _MiniTrendPainter(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < .0001
        ? 1.0
        : maxValue - minValue;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y =
          size.height -
          ((values[i] - minValue) / range * (size.height - 20)) -
          10;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _CanliHavaKart extends StatefulWidget {
  final VoidCallback onTap;
  const _CanliHavaKart({required this.onTap});

  @override
  State<_CanliHavaKart> createState() => _CanliHavaKartState();
}

class _CanliHaberKart extends StatefulWidget {
  final VoidCallback onTap;
  const _CanliHaberKart({required this.onTap});

  @override
  State<_CanliHaberKart> createState() => _CanliHaberKartState();
}

class _CanliHaberKartState extends State<_CanliHaberKart> {
  List<Map<String, dynamic>> _news = const [];
  Timer? _ticker;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _news.length < 2) return;
      setState(() => _index = (_index + 1) % _news.length);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse(ApiConfig.news).replace(
        queryParameters: {
          'period': '7d',
          'category': 'tumu',
          'page': '1',
          'limit': '30',
        },
      );
      final response = await ApiClient.get(
        uri,
        timeout: const Duration(seconds: 30),
        cacheTtl: const Duration(minutes: 2),
      );
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final raw = body is Map ? (body['news'] ?? body['data']) : null;
      if (raw is! List) return;
      final visual = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) {
            final image =
                '${item['imageUrl'] ?? item['image'] ?? item['urlToImage'] ?? ''}'
                    .trim();
            return image.startsWith('http://') || image.startsWith('https://');
          })
          .take(12)
          .toList();
      if (mounted && visual.isNotEmpty)
        setState(() {
          _news = visual;
          _index = 0;
        });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final item = _news.isEmpty
        ? null
        : _news[_index.clamp(0, _news.length - 1)];
    final image = '${item?['imageUrl'] ?? ''}';
    final title = '${item?['title'] ?? 'Görselli haberler yükleniyor…'}';
    return AspectRatio(
      aspectRatio: 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (_, page) {
                  final turn = (1 - animation.value) * 0.72;
                  return Opacity(
                    opacity: animation.value.clamp(0, 1),
                    child: Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0018)
                        ..rotateY(turn),
                      child: page,
                    ),
                  );
                },
              ),
              child: Container(
                key: ValueKey(image),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  image: image.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(image),
                          fit: BoxFit.cover,
                          colorFilter: const ColorFilter.mode(
                            Color(0x99020A13),
                            BlendMode.darken,
                          ),
                        ),
                  gradient: image.isEmpty
                      ? const LinearGradient(
                          colors: [Color(0xFF17324A), Color(0xFF0C192B)],
                        )
                      : null,
                  border: Border.all(
                    color: TrendoraColors.secondary.withValues(alpha: 0.45),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _GazeteSayfasiOnizleme(imageUrl: image),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'HABER MERKEZİ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.swipe_rounded,
                          color: Color(0xFFBCEEFF),
                          size: 16,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item?['source'] ?? item?['feedSource'] ?? 'Canlı haber akışı'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFBCEEFF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GazeteSayfasiOnizleme extends StatelessWidget {
  final String imageUrl;
  const _GazeteSayfasiOnizleme({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 42,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 3,
            child: Transform.rotate(
              angle: .10,
              child: Container(
                width: 36,
                height: 35,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9E6EE),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF6D8798)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 1,
            top: 1,
            child: Container(
              width: 38,
              height: 37,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 5,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF17324A),
                        child: Icon(
                          Icons.article_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF17324A),
                          child: Icon(
                            Icons.article_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanliFirsatKart extends StatefulWidget {
  final VoidCallback onTap;
  const _CanliFirsatKart({required this.onTap});

  @override
  State<_CanliFirsatKart> createState() => _CanliFirsatKartState();
}

class _CanliFirsatKartState extends State<_CanliFirsatKart>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _items = const [];
  late final AnimationController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..repeat();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse(
        ApiConfig.opportunities,
      ).replace(queryParameters: {'limit': '40'});
      final response = await ApiClient.get(
        uri,
        timeout: const Duration(seconds: 30),
        cacheTtl: const Duration(minutes: 2),
      );
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final raw = body is Map
          ? (body['opportunities'] ?? body['items'] ?? body['data'])
          : null;
      if (raw is! List) return;
      final opportunities = <Map<String, dynamic>>[];
      final seenTitles = <String>{};
      final storeCounts = <String, int>{};
      for (final rawItem in raw.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final title = _text(item, const [
          'title',
          'name',
          'productName',
          'description',
        ]);
        final store =
            '${item['store'] ?? item['market'] ?? item['source'] ?? ''}'
                .trim()
                .toLowerCase();
        if (title.isEmpty || seenTitles.contains(title.toLowerCase())) continue;
        if ((storeCounts[store] ?? 0) >= 3) continue;
        seenTitles.add(title.toLowerCase());
        storeCounts[store] = (storeCounts[store] ?? 0) + 1;
        opportunities.add(item);
        if (opportunities.length >= 18) break;
      }
      if (mounted && opportunities.isNotEmpty)
        setState(() => _items = opportunities);
    } catch (_) {}
  }

  String _text(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = '${item[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    const rowHeight = 54.0;
    final segmentHeight = _items.length * rowHeight;
    return AspectRatio(
      aspectRatio: .98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14382F), Color(0xFF071713)],
                ),
                border: Border.all(
                  color: TrendoraColors.success.withValues(alpha: .45),
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(13, 11, 13, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_offer_rounded,
                          color: TrendoraColors.success,
                          size: 20,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'CANLI FIRSATLAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_double_arrow_up_rounded,
                          color: Color(0xFF9CF0C8),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF245445)),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                              'Fırsatlar yükleniyor…',
                              style: TextStyle(
                                color: Color(0xFF9FC5B5),
                                fontSize: 11,
                              ),
                            ),
                          )
                        : ClipRect(
                            child: AnimatedBuilder(
                              animation: _scroll,
                              builder: (_, __) => Transform.translate(
                                offset: Offset(
                                  0,
                                  -_scroll.value * segmentHeight,
                                ),
                                child: OverflowBox(
                                  alignment: Alignment.topCenter,
                                  minHeight: segmentHeight * 2,
                                  maxHeight: segmentHeight * 2,
                                  child: Column(
                                    children: [_items, _items]
                                        .expand((group) => group)
                                        .map((item) {
                                          final title = _text(item, const [
                                            'title',
                                            'name',
                                            'productName',
                                            'description',
                                          ]);
                                          final store = _text(item, const [
                                            'store',
                                            'market',
                                            'source',
                                            'brand',
                                          ]);
                                          final price = _text(item, const [
                                            'price',
                                            'newPrice',
                                            'salePrice',
                                            'currentPrice',
                                          ]);
                                          return SizedBox(
                                            height: rowHeight,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 5,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          store.isEmpty
                                                              ? 'Fırsat'
                                                              : store
                                                                    .toUpperCase(),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFF8FE4B9,
                                                                ),
                                                                fontSize: 8.8,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        ),
                                                      ),
                                                      if (price.isNotEmpty)
                                                        Text(
                                                          price,
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFFFFD166,
                                                                ),
                                                                fontSize: 9.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanliHavaKartState extends State<_CanliHavaKart>
    with WidgetsBindingObserver {
  String _location = 'Konum bekleniyor';
  String _description = 'Hava Merkezini açarak konumunu algıla';
  int? _code;
  double? _temperature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _location =
          prefs.getString('weather_card_location') ?? 'Konum bekleniyor';
      _description =
          prefs.getString('weather_card_description') ??
          'Hava Merkezini açarak konumunu algıla';
      _code = prefs.getInt('weather_card_code');
      _temperature = prefs.getDouble('weather_card_temperature');
    });
  }

  IconData get _icon {
    final code = _code ?? -1;
    if (code == 0 || code == 1) return Icons.wb_sunny_rounded;
    if ([2, 3, 45, 48].contains(code)) return Icons.cloud_rounded;
    if (code >= 71 && code <= 86) return Icons.ac_unit_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    if (code >= 51 && code <= 67 || code >= 80 && code <= 82)
      return Icons.water_drop_rounded;
    return Icons.cloud_outlined;
  }

  Color get _color {
    final code = _code ?? -1;
    if (code == 0 || code == 1) return const Color(0xFFFFC857);
    if (code >= 71 && code <= 86) return const Color(0xFFBDEBFF);
    if (code >= 95) return const Color(0xFFB69CFF);
    return const Color(0xFF6EE7F9);
  }

  @override
  Widget build(BuildContext context) {
    final temp = _temperature == null
        ? ''
        : ' • ${_temperature!.toStringAsFixed(0)}°';
    return _PremiumYatayKart(
      baslik: 'Akıllı Hava Merkezi',
      aciklama: '$_location$temp • $_description',
      icon: _icon,
      accent: _color,
      onTap: widget.onTap,
    );
  }
}

class _PremiumUstBar extends StatelessWidget {
  final VoidCallback onAyarlar;

  const _PremiumUstBar({required this.onAyarlar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TrendoraColors.primary, TrendoraColors.secondary],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: TrendoraColors.primary.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 23),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRENDORA',
                style: TextStyle(
                  color: TrendoraColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Akıllı trend platformu',
                style: TextStyle(
                  color: TrendoraColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAyarlar,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: TrendoraColors.textSecondary,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnaMenuHero extends StatefulWidget {
  const _AnaMenuHero();

  @override
  State<_AnaMenuHero> createState() => _AnaMenuHeroState();
}

class _AnaMenuHeroState extends State<_AnaMenuHero>
    with TickerProviderStateMixin {
  late final AnimationController _dunya;
  late final AnimationController _bant;
  Timer? _yenileme;
  List<Map<String, dynamic>> _veriler = const [];

  @override
  void initState() {
    super.initState();
    _dunya = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _bant = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 65),
    )..repeat();
    _piyasayiGetir();
    _yenileme = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _piyasayiGetir(),
    );
  }

  @override
  void dispose() {
    _yenileme?.cancel();
    _dunya.dispose();
    _bant.dispose();
    super.dispose();
  }

  Future<void> _piyasayiGetir() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/trends/market-board'),
        timeout: const Duration(seconds: 30),
        cacheTtl: const Duration(minutes: 2),
      );
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final items = body is Map ? body['items'] : null;
      if (response.statusCode == 200 && items is List && mounted) {
        setState(
          () => _veriler = items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
      }
    } catch (_) {}
  }

  bool get _gunduz {
    final hour = DateTime.now().hour;
    return hour >= 7 && hour < 19;
  }

  String _fiyat(Map<String, dynamic> item) {
    final value = item['price'];
    if (value is! num) return '-';
    final symbol = '${item['symbol'] ?? ''}';
    final label = '${item['label'] ?? ''}';
    final currency = label == 'BIST 100' || symbol.endsWith('.IS')
        ? ''
        : '${item['currency'] ?? ''}';
    final digits = value.abs() < 100
        ? 2
        : value.abs() < 1000
        ? 2
        : 0;
    return '${value.toStringAsFixed(digits).replaceAll('.', ',')}${currency.isEmpty ? '' : ' $currency'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 19, 17, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172B49), Color(0xFF101D32), Color(0xFF0B1628)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF264465)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x34000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TrendoraColors.primary.withValues(alpha: 0.20),
                    TrendoraColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: _gunduz
                            ? const Alignment(-0.45, -0.45)
                            : const Alignment(0.55, 0.4),
                        colors: _gunduz
                            ? const [
                                Color(0xFF74D8FF),
                                Color(0xFF125D87),
                                Color(0xFF07182A),
                              ]
                            : const [
                                Color(0xFF7891C7),
                                Color(0xFF18294A),
                                Color(0xFF050A16),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: TrendoraColors.primary.withValues(alpha: 0.34),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: TrendoraColors.primary.withValues(alpha: 0.16),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _dunya,
                      builder: (_, child) => Transform.rotate(
                        angle: _dunya.value * 6.283185307,
                        child: child,
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            _CanliNokta(),
                            SizedBox(width: 8),
                            Text(
                              'SİSTEM AKTİF',
                              style: TextStyle(
                                color: TrendoraColors.success,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 7),
                        Wrap(
                          spacing: 10,
                          runSpacing: 5,
                          children: _veriler.take(3).map((item) {
                            final change = item['changePercent'] is num
                                ? item['changePercent'] as num
                                : null;
                            final positive = (change ?? 0) >= 0;
                            return Text(
                              '${item['label']}  ${_fiyat(item)}${change == null ? '' : '  ${positive ? '+' : ''}${change.toStringAsFixed(2)}%'}',
                              style: TextStyle(
                                color: positive
                                    ? const Color(0xFF7BE7B4)
                                    : const Color(0xFFFF8B94),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            );
                          }).toList(),
                        ),
                        if (_veriler.isEmpty)
                          const Text(
                            'Piyasa verileri yükleniyor…',
                            style: TextStyle(
                              color: TrendoraColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 25,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF06111E),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF1C3B53)),
                ),
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final stocks = _veriler.skip(3).toList();
                      const itemWidth = 150.0;
                      final segmentWidth = stocks.length * itemWidth;
                      if (stocks.isEmpty) return const SizedBox.shrink();
                      return AnimatedBuilder(
                        animation: _bant,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(-_bant.value * segmentWidth, 0),
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: segmentWidth * 2,
                            maxWidth: segmentWidth * 2,
                            child: Row(
                              children: [stocks, stocks]
                                  .expand((group) => group)
                                  .map((item) {
                                    final change = item['changePercent'] is num
                                        ? item['changePercent'] as num
                                        : null;
                                    final positive = (change ?? 0) >= 0;
                                    return SizedBox(
                                      width: itemWidth,
                                      child: Center(
                                        child: Text(
                                          '${item['label']}  ${_fiyat(item)}  ${change == null ? '' : '${positive ? '▲' : '▼'}${change.abs().toStringAsFixed(2)}%'}',
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: positive
                                                ? const Color(0xFF74E5AF)
                                                : const Color(0xFFFF8993),
                                            fontSize: 10.2,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CanliNokta extends StatelessWidget {
  const _CanliNokta();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: TrendoraColors.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: TrendoraColors.success,
            blurRadius: 9,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _BolumBasligi extends StatelessWidget {
  final String baslik;
  final String aciklama;

  const _BolumBasligi({required this.baslik, required this.aciklama});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baslik,
                style: const TextStyle(
                  color: TrendoraColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                aciklama,
                style: const TextStyle(
                  color: TrendoraColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 31,
          height: 1,
          color: TrendoraColors.primary.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}

class _PremiumAnaKart extends StatelessWidget {
  final String etiket;
  final String baslik;
  final String aciklama;
  final String bilgi;
  final IconData icon;
  final Color accent;
  final Color ikincilRenk;
  final VoidCallback onTap;

  const _PremiumAnaKart({
    required this.etiket,
    required this.baslik,
    required this.aciklama,
    required this.bilgi,
    required this.icon,
    required this.accent,
    required this.ikincilRenk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(27),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF182D4B), Color(0xFF0E1C31)],
            ),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -16,
                child: Icon(
                  icon,
                  color: accent.withValues(alpha: 0.075),
                  size: 118,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, ikincilRenk],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.27),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 27),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _CanliNokta(),
                            const SizedBox(width: 7),
                            Text(
                              bilgi,
                              style: TextStyle(
                                color: accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    etiket,
                    style: TextStyle(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.25,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    baslik,
                    style: const TextStyle(
                      color: TrendoraColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.only(right: 38),
                    child: Text(
                      aciklama,
                      style: const TextStyle(
                        color: TrendoraColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'ANALİZİ AÇ',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                        size: 17,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumKucukKart extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _PremiumKucukKart({
    required this.baslik,
    required this.aciklama,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF152843), Color(0xFF0D192C)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 22,
                  offset: Offset(0, 11),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(icon, color: accent, size: 24),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: accent.withValues(alpha: 0.85),
                      size: 19,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  baslik,
                  style: const TextStyle(
                    color: TrendoraColors.textPrimary,
                    fontSize: 16,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  aciklama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TrendoraColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumYatayKart extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool kilitli;

  const _PremiumYatayKart({
    required this.baslik,
    required this.aciklama,
    required this.icon,
    required this.accent,
    this.onTap,
    this.kilitli = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xC40E1A2D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(
                        color: TrendoraColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      aciklama,
                      style: const TextStyle(
                        color: TrendoraColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (kilitli)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'YAKINDA',
                    style: TextStyle(
                      color: accent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: TrendoraColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnaMenuArkaPlanPainter extends CustomPainter {
  const _AnaMenuArkaPlanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint cizgi = Paint()
      ..color = TrendoraColors.secondary.withValues(alpha: 0.035)
      ..strokeWidth = 0.7;

    const double aralik = 38;

    for (double x = -size.height; x < size.width; x += aralik) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        cizgi,
      );
    }

    final Paint nokta = Paint()
      ..color = TrendoraColors.primary.withValues(alpha: 0.08);

    for (double y = 90; y < size.height; y += 120) {
      for (double x = 28; x < size.width; x += 105) {
        canvas.drawCircle(Offset(x, y), 1.2, nokta);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnaMenuArkaPlanPainter oldDelegate) => false;
}

class _AcilisHero extends StatelessWidget {
  const _AcilisHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [TrendoraColors.primary, TrendoraColors.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: TrendoraColors.primary.withValues(alpha: 0.34),
                blurRadius: 42,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 54),
        ),
        const SizedBox(height: 30),
        const Text(
          'TRENDORA',
          style: TextStyle(
            color: TrendoraColors.textPrimary,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 5.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Dünyadaki fırsatları, haberleri ve yükselen eğilimleri tek bakışta keşfet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TrendoraColors.textSecondary,
            fontSize: 16,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _MarkaRozeti extends StatelessWidget {
  const _MarkaRozeti();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: TrendoraColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: TrendoraColors.accent,
            size: 16,
          ),
          SizedBox(width: 7),
          Text(
            'AKILLI TREND PLATFORMU',
            style: TextStyle(
              color: TrendoraColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _CanliDurumSatiri() {
  return const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _DurumNoktasi(metin: 'Haberler'),
      SizedBox(width: 16),
      _DurumNoktasi(metin: 'Fırsatlar'),
      SizedBox(width: 16),
      _DurumNoktasi(metin: 'Trendler'),
    ],
  );
}

class _DurumNoktasi extends StatelessWidget {
  final String metin;

  const _DurumNoktasi({required this.metin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: TrendoraColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          metin,
          style: const TextStyle(
            color: TrendoraColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PremiumArkaPlan extends StatelessWidget {
  final bool sade;

  const _PremiumArkaPlan({this.sade = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07101F), Color(0xFF0A1426), Color(0xFF07101F)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: sade ? -120 : -70,
            right: -100,
            child: _IsikHalesi(
              boyut: sade ? 260 : 330,
              renk: TrendoraColors.primary,
            ),
          ),
          Positioned(
            bottom: sade ? -150 : -90,
            left: -120,
            child: _IsikHalesi(
              boyut: sade ? 280 : 360,
              renk: TrendoraColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IsikHalesi extends StatelessWidget {
  final double boyut;
  final Color renk;

  const _IsikHalesi({required this.boyut, required this.renk});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [renk.withValues(alpha: 0.16), renk.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _MenuOgesi {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback? onTap;

  const _MenuOgesi({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    this.onTap,
  });
}
