class InterestDefinition {
  const InterestDefinition({required this.id, required this.label});

  final String id;
  final String label;
}

class TrendoraInterestCatalog {
  TrendoraInterestCatalog._();

  static const List<InterestDefinition> all = [
    InterestDefinition(id: 'stock_market', label: 'Borsa'),
    InterestDefinition(id: 'gold', label: 'Altın'),
    InterestDefinition(id: 'foreign_exchange', label: 'Döviz'),
    InterestDefinition(id: 'crypto', label: 'Kripto'),
    InterestDefinition(id: 'economy', label: 'Ekonomi'),
    InterestDefinition(id: 'politics', label: 'Siyaset'),
    InterestDefinition(id: 'sports', label: 'Spor'),
    InterestDefinition(id: 'automotive', label: 'Otomobil'),
    InterestDefinition(id: 'technology', label: 'Teknoloji'),
    InterestDefinition(id: 'science', label: 'Bilim'),
    InterestDefinition(id: 'space', label: 'Uzay'),
    InterestDefinition(id: 'health', label: 'Sağlık'),
    InterestDefinition(id: 'travel', label: 'Seyahat'),
    InterestDefinition(id: 'market_opportunities', label: 'Market fırsatları'),
    InterestDefinition(
      id: 'shopping_opportunities',
      label: 'Alışveriş fırsatları',
    ),
    InterestDefinition(id: 'local_news', label: 'Yerel haberler'),
    InterestDefinition(id: 'world_agenda', label: 'Dünya gündemi'),
  ];

  static final Set<String> ids = all.map((item) => item.id).toSet();

  static bool contains(String id) => ids.contains(id);
}
