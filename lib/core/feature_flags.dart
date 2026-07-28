class FeatureFlags {
  FeatureFlags._();

  /// AI altyapısı kodda kalır, açıkça etkinleştirilmedikçe kullanılmaz.
  static const bool aiEnabled = bool.fromEnvironment(
    'TRENDORA_ENABLE_AI',
    defaultValue: false,
  );

  /// Premium günlük özet, genel AI özelliğinden bağımsız etkinleştirilir.
  static const bool premiumAiSummaryEnabled = bool.fromEnvironment(
    'TRENDORA_ENABLE_PREMIUM_AI_SUMMARY',
    defaultValue: false,
  );
}
