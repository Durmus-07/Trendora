import 'package:flutter/material.dart';

import '../core/trend_technical_analysis.dart';

class TrendoraTechnicalViewCard extends StatelessWidget {
  const TrendoraTechnicalViewCard({super.key, required this.analysis});

  final TrendTeknikAnalizi analysis;

  @override
  Widget build(BuildContext context) {
    final basic = <({String label, String value})>[
      if (analysis.rsi14 != null)
        (label: 'RSI', value: _number(analysis.rsi14)),
      if (analysis.macd != null)
        (
          label: 'MACD',
          value: analysis.macdSignal == null
              ? _number(analysis.macd)
              : '${_number(analysis.macd)} / ${_number(analysis.macdSignal)}',
        ),
      if (analysis.atr14 != null)
        (label: 'ATR', value: _number(analysis.atr14)),
      if (analysis.ema20 != null)
        (label: 'EMA20', value: _number(analysis.ema20)),
      if (analysis.ema50 != null)
        (label: 'EMA50', value: _number(analysis.ema50)),
      if (analysis.supportLevels.isNotEmpty)
        (
          label: 'Destek',
          value: analysis.supportLevels.map(_number).join(' / '),
        ),
      if (analysis.resistanceLevels.isNotEmpty)
        (
          label: 'Direnç',
          value: analysis.resistanceLevels.map(_number).join(' / '),
        ),
    ];
    final details = <({String label, String value})>[
      if (analysis.sma != null) (label: 'SMA', value: _number(analysis.sma)),
      if (analysis.sma100 != null)
        (label: 'SMA100', value: _number(analysis.sma100)),
      if (analysis.ema100 != null)
        (label: 'EMA100', value: _number(analysis.ema100)),
      if (analysis.ema200 != null)
        (label: 'EMA200', value: _number(analysis.ema200)),
      if (analysis.bollingerUpper != null)
        (label: 'Bollinger üst', value: _number(analysis.bollingerUpper)),
      if (analysis.bollingerMiddle != null)
        (label: 'Bollinger orta', value: _number(analysis.bollingerMiddle)),
      if (analysis.bollingerLower != null)
        (label: 'Bollinger alt', value: _number(analysis.bollingerLower)),
    ];

    return Semantics(
      container: true,
      label: 'Teknik görünüm',
      child: Container(
        key: const Key('teknik-gorunum-karti'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2034),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF285D75)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.query_stats_rounded, color: Color(0xFF6EE7F9)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Teknik Görünüm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (analysis.isInsufficient)
              _insufficientMessage()
            else ...[
              _summary(),
              if (_hasTrend) ...[
                const SizedBox(height: 15),
                _sectionTitle('VADE GÖRÜNÜMÜ'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (analysis.shortTermTrend != null)
                      Expanded(
                        child: _trend('Kısa Vade', analysis.shortTermTrend!),
                      ),
                    if (analysis.shortTermTrend != null &&
                        analysis.mediumTermTrend != null)
                      const SizedBox(width: 7),
                    if (analysis.mediumTermTrend != null)
                      Expanded(
                        child: _trend('Orta Vade', analysis.mediumTermTrend!),
                      ),
                    if (analysis.mediumTermTrend != null &&
                        analysis.longTermTrend != null)
                      const SizedBox(width: 7),
                    if (analysis.longTermTrend != null)
                      Expanded(
                        child: _trend('Uzun Vade', analysis.longTermTrend!),
                      ),
                  ],
                ),
              ],
              if (basic.isNotEmpty) ...[
                const SizedBox(height: 15),
                _sectionTitle('TEMEL GÖSTERGELER'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: basic
                      .map((item) => _indicator(item.label, item.value))
                      .toList(growable: false),
                ),
              ],
              if (details.isNotEmpty ||
                  analysis.scoreContributions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: Material(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      key: const Key('teknik-gorunum-detaylari'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 5),
                      iconColor: const Color(0xFF6EE7F9),
                      collapsedIconColor: const Color(0xFF7E9BB2),
                      title: const Text(
                        'Diğer göstergeler',
                        style: TextStyle(
                          color: Color(0xFFB7CCDC),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...details.map(
                                (item) => _indicator(item.label, item.value),
                              ),
                              ...analysis.scoreContributions.entries.map(
                                (entry) => _indicator(
                                  _contributionLabel(entry.key),
                                  entry.value >= 0
                                      ? '+${_number(entry.value)}'
                                      : _number(entry.value),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 11),
            const Text(
              'Bu değerlendirme yatırım tavsiyesi değildir.',
              style: TextStyle(
                color: Color(0xFF7F98AD),
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (analysis.technicalScore != null)
              _chip('Teknik skor', '${analysis.technicalScore}/100'),
            if (analysis.confidenceLevel != null)
              _chip('Güven', analysis.confidenceLevel!),
            if (analysis.dataSufficiency.label != null)
              _chip('Veri', analysis.dataSufficiency.label!),
            if (analysis.dataPointCount != null)
              _chip('Gözlem', '${analysis.dataPointCount}'),
          ],
        ),
        if (analysis.dataTime != null) ...[
          const SizedBox(height: 10),
          Text(
            'Son veri: ${_date(analysis.dataTime!)}',
            style: const TextStyle(color: Color(0xFF8FA9C1), fontSize: 11.5),
          ),
        ],
      ],
    );
  }

  bool get _hasTrend =>
      analysis.shortTermTrend != null ||
      analysis.mediumTermTrend != null ||
      analysis.longTermTrend != null;

  static Widget _insufficientMessage() => Container(
    key: const Key('teknik-veri-yetersiz'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF16283A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF385069)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 19, color: Color(0xFFFFD166)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Teknik analiz için yeterli piyasa verisi bulunamadı.',
            style: TextStyle(
              color: Color(0xFFD7E4EE),
              height: 1.4,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    ),
  );

  static Widget _sectionTitle(String value) => Text(
    value,
    style: const TextStyle(
      color: Color(0xFF7893AA),
      fontSize: 10.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.9,
    ),
  );

  static Widget _chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1928),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1B3A52)),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: Color(0xFF7893AA)),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 11),
    ),
  );

  static Widget _trend(String label, String value) => Container(
    constraints: const BoxConstraints(minHeight: 72),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1928),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFF1A4058)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF7893AA), fontSize: 9.5),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFDDEAF3),
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  static Widget _indicator(String label, String value) => Container(
    constraints: const BoxConstraints(minWidth: 92),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF11283B),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF7893AA), fontSize: 9.5),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  static String _number(double? value) {
    if (value == null || !value.isFinite) return '-';
    final digits = value.abs() >= 100
        ? 2
        : value.abs() >= 1
        ? 3
        : 4;
    return value.toStringAsFixed(digits).replaceAll(RegExp(r'\.?0+$'), '');
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _contributionLabel(String key) =>
      const {
        'movingAverages': 'Ortalamalar',
        'averageAlignment': 'Ortalama uyumu',
        'rsi': 'RSI katkısı',
        'macd': 'MACD katkısı',
        'bollingerPosition': 'Bollinger katkısı',
        'supportResistance': 'Seviye katkısı',
        'atrVolatility': 'ATR katkısı',
        'volume': 'Hacim katkısı',
        'dailyChange': 'Günlük değişim',
      }[key] ??
      key;
}
