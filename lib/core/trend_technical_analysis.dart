class TrendTeknikAnalizi {
  final int? technicalScore;
  final int? confidenceScore;
  final String? confidenceLevel;
  final TrendVeriYeterliligi dataSufficiency;
  final int? dataPointCount;
  final DateTime? dataTime;
  final String? shortTermTrend;
  final String? mediumTermTrend;
  final String? longTermTrend;
  final double? rsi14;
  final double? macd;
  final double? macdSignal;
  final double? sma;
  final double? sma100;
  final double? ema20;
  final double? ema50;
  final double? ema100;
  final double? ema200;
  final double? bollingerUpper;
  final double? bollingerMiddle;
  final double? bollingerLower;
  final double? atr14;
  final List<double> supportLevels;
  final List<double> resistanceLevels;
  final Map<String, double> scoreContributions;

  const TrendTeknikAnalizi({
    required this.technicalScore,
    required this.confidenceScore,
    required this.confidenceLevel,
    required this.dataSufficiency,
    required this.dataPointCount,
    required this.dataTime,
    required this.shortTermTrend,
    required this.mediumTermTrend,
    required this.longTermTrend,
    required this.rsi14,
    required this.macd,
    required this.macdSignal,
    required this.sma,
    required this.sma100,
    required this.ema20,
    required this.ema50,
    required this.ema100,
    required this.ema200,
    required this.bollingerUpper,
    required this.bollingerMiddle,
    required this.bollingerLower,
    required this.atr14,
    required this.supportLevels,
    required this.resistanceLevels,
    required this.scoreContributions,
  });

  const TrendTeknikAnalizi.empty()
    : technicalScore = null,
      confidenceScore = null,
      confidenceLevel = null,
      dataSufficiency = const TrendVeriYeterliligi.empty(),
      dataPointCount = null,
      dataTime = null,
      shortTermTrend = null,
      mediumTermTrend = null,
      longTermTrend = null,
      rsi14 = null,
      macd = null,
      macdSignal = null,
      sma = null,
      sma100 = null,
      ema20 = null,
      ema50 = null,
      ema100 = null,
      ema200 = null,
      bollingerUpper = null,
      bollingerMiddle = null,
      bollingerLower = null,
      atr14 = null,
      supportLevels = const [],
      resistanceLevels = const [],
      scoreContributions = const {};

  factory TrendTeknikAnalizi.fromJson(Map<String, dynamic> json) {
    List<double> numberList(dynamic value) => _list(
      value,
    ).map(_number).whereType<double>().take(4).toList(growable: false);
    List<double> priceLevelList(dynamic value) => numberList(
      value,
    ).where((number) => number > 0).toList(growable: false);
    final contributions = <String, double>{};
    for (final entry in _map(json['scoreContributions']).entries) {
      final value = _number(entry.value);
      if (value != null) contributions[entry.key] = value;
    }

    return TrendTeknikAnalizi(
      technicalScore: _integer(
        json['technicalScore'] ?? json['score'],
        min: 0,
        max: 100,
      ),
      confidenceScore: _integer(json['confidenceScore'], min: 0, max: 100),
      confidenceLevel: _text(json['confidenceLevel']),
      dataSufficiency: TrendVeriYeterliligi.fromJson(
        _map(json['dataSufficiency']),
      ),
      dataPointCount: _integer(json['dataPointCount'], min: 0),
      dataTime: _date(json['dataTime']),
      shortTermTrend: _text(json['shortTermTrend']),
      mediumTermTrend: _text(json['mediumTermTrend']),
      longTermTrend: _text(json['longTermTrend']),
      rsi14: _number(json['rsi14']),
      macd: _number(json['macd']),
      macdSignal: _number(json['macdSignal']),
      sma: _number(json['sma'] ?? json['sma20']),
      sma100: _number(json['sma100']),
      ema20: _number(json['ema20']),
      ema50: _number(json['ema50']),
      ema100: _number(json['ema100']),
      ema200: _number(json['ema200']),
      bollingerUpper: _number(json['bollingerUpper']),
      bollingerMiddle: _number(json['bollingerMiddle']),
      bollingerLower: _number(json['bollingerLower']),
      atr14: _number(json['atr14']),
      supportLevels: priceLevelList(json['supportLevels']),
      resistanceLevels: priceLevelList(json['resistanceLevels']),
      scoreContributions: Map.unmodifiable(contributions),
    );
  }

  bool get isInsufficient =>
      dataSufficiency.status == 'insufficient' ||
      confidenceLevel == 'Veri Yetersiz';

  bool get hasAny =>
      technicalScore != null ||
      confidenceLevel != null ||
      dataSufficiency.hasValue ||
      dataPointCount != null ||
      dataTime != null ||
      shortTermTrend != null ||
      mediumTermTrend != null ||
      longTermTrend != null ||
      rsi14 != null ||
      macd != null ||
      atr14 != null ||
      ema20 != null ||
      ema50 != null ||
      supportLevels.isNotEmpty ||
      resistanceLevels.isNotEmpty;
}

class TrendVeriYeterliligi {
  final String? status;
  final String? label;
  final int? available;
  final int? required;

  const TrendVeriYeterliligi({
    required this.status,
    required this.label,
    required this.available,
    required this.required,
  });

  const TrendVeriYeterliligi.empty()
    : status = null,
      label = null,
      available = null,
      required = null;

  factory TrendVeriYeterliligi.fromJson(Map<String, dynamic> json) {
    return TrendVeriYeterliligi(
      status: _text(json['status']),
      label: _text(json['label']),
      available: _integer(json['available'], min: 0),
      required: _integer(json['required'], min: 0),
    );
  }

  bool get hasValue =>
      status != null || label != null || available != null || required != null;
}

double? _number(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }
  var text = value.toString().trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (text.isEmpty) return null;
  if (text.contains('.') && text.contains(',')) {
    text = text.lastIndexOf(',') > text.lastIndexOf('.')
        ? text.replaceAll('.', '').replaceAll(',', '.')
        : text.replaceAll(',', '');
  } else if (text.contains(',')) {
    text = text.replaceAll(',', '.');
  }
  final number = double.tryParse(text);
  return number != null && number.isFinite ? number : null;
}

int? _integer(dynamic value, {int? min, int? max}) {
  final number = _number(value);
  if (number == null) return null;
  var result = number.round();
  if (min != null && result < min) result = min;
  if (max != null && result > max) result = max;
  return result;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is num && value.isFinite) {
    final milliseconds = value.abs() < 1000000000000
        ? (value * 1000).round()
        : value.round();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<dynamic> _list(dynamic value) => value is List ? value : const [];
