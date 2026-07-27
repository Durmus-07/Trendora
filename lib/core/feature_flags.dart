class FeatureFlags {
  FeatureFlags._();

  /// AI altyapısı kodda kalır, açıkça etkinleştirilmedikçe kullanılmaz.
  static const bool aiEnabled = bool.fromEnvironment(
    'TRENDORA_ENABLE_AI',
    defaultValue: false,
  );
}
