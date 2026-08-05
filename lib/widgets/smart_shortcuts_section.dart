import 'package:flutter/material.dart';

import '../akilli_kisayollar_sayfasi.dart';

class SmartShortcutsSection extends StatefulWidget {
  const SmartShortcutsSection({super.key});

  @override
  State<SmartShortcutsSection> createState() => _SmartShortcutsSectionState();
}

class _SmartShortcutsSectionState extends State<SmartShortcutsSection> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _openQuery(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AkilliKisayollarSayfasi(initialCommand: query),
      ),
    );
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
        const SizedBox(height: 14),
      ],
    );
  }
}
