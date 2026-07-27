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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AkilliKisayollarSayfasi(initialCommand: item.command),
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
          'AKILLI KISAYOLLAR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 9),
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
