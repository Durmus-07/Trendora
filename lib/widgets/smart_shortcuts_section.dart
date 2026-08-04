import 'package:flutter/material.dart';

import '../akilli_kisayollar_sayfasi.dart';
import '../core/shortcuts/smart_command_service.dart';
import '../core/shortcuts/smart_shortcut_store.dart';

class SmartShortcutsSection extends StatefulWidget {
  const SmartShortcutsSection({super.key});

  @override
  State<SmartShortcutsSection> createState() => _SmartShortcutsSectionState();
}

class _SmartShortcutsSectionState extends State<SmartShortcutsSection> {
  List<SmartShortcutDefinition> _items = SmartShortcutCatalog.all;
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final runtime = await SmartCommandRuntime.create();
      final items = SmartShortcutStore(
        runtime.preferences,
      ).load(runtime.userId);
      if (mounted) setState(() => _items = items);
    } catch (_) {}
  }

  Future<void> _open(SmartShortcutDefinition item) async {
    await _openQuery(item.command);
  }

  Future<void> _openQuery(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AkilliKisayollarSayfasi(initialCommand: query),
      ),
    );
    await _loadOrder();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRENDORA ARAMA MOTORU',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Haberleri, fırsatları ve piyasaları arayın veya bir soru sorun.',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _queryController,
          textInputAction: TextInputAction.search,
          onSubmitted: _openQuery,
          decoration: InputDecoration(
            hintText: 'Trendora’da ara veya bir şey sor…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Ara',
              onPressed: () => _openQuery(_queryController.text),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Örnek aramalar',
          style: TextStyle(color: Colors.white60, fontSize: 10),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _items[index];
              return ActionChip(
                label: Text(item.label),
                onPressed: () => _open(item),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
