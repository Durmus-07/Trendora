import 'package:flutter/material.dart';

import 'core/shortcuts/smart_command_service.dart';
import 'core/shortcuts/smart_shortcut_store.dart';
import 'firsatlar_sayfasi.dart';
import 'haberler_sayfasi.dart';
import 'hava_merkezi_sayfasi.dart';
import 'trend_tahmini_sayfasi.dart';

class AkilliKisayollarSayfasi extends StatefulWidget {
  const AkilliKisayollarSayfasi({super.key, this.initialCommand});

  final String? initialCommand;

  @override
  State<AkilliKisayollarSayfasi> createState() =>
      _AkilliKisayollarSayfasiState();
}

class _AkilliKisayollarSayfasiState extends State<AkilliKisayollarSayfasi> {
  final _controller = TextEditingController();
  SmartCommandRuntime? _runtime;
  List<SmartShortcutDefinition> _shortcuts = const [];
  SmartCommandResult? _result;
  bool _loading = true;
  bool _executing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final runtime = await SmartCommandRuntime.create();
      final shortcuts = SmartShortcutStore(
        runtime.preferences,
      ).load(runtime.userId);
      if (!mounted) return;
      setState(() {
        _runtime = runtime;
        _shortcuts = shortcuts;
        _loading = false;
      });
      final initial = widget.initialCommand?.trim() ?? '';
      if (initial.isNotEmpty) {
        _controller.text = initial;
        await _execute(initial);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _execute([String? value]) async {
    final command = (value ?? _controller.text).trim();
    final runtime = _runtime;
    if (command.isEmpty || runtime == null || _executing) return;
    setState(() => _executing = true);
    final result = await runtime.service.execute(command);
    if (!mounted) return;
    setState(() {
      _result = result;
      _executing = false;
    });
  }

  Future<void> _reorder() async {
    final draft = List<SmartShortcutDefinition>.from(_shortcuts);
    final result = await showModalBottomSheet<List<SmartShortcutDefinition>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Kısayol Sırası',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ReorderableListView(
                    onReorderItem: (oldIndex, newIndex) {
                      modalSetState(() {
                        draft.insert(newIndex, draft.removeAt(oldIndex));
                      });
                    },
                    children: [
                      for (final item in draft)
                        ListTile(
                          key: ValueKey(item.id),
                          leading: const Icon(Icons.drag_handle_rounded),
                          title: Text(item.label),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, draft),
                    child: const Text('Sırayı Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || _runtime == null) return;
    await SmartShortcutStore(
      _runtime!.preferences,
    ).save(_runtime!.userId, result);
    if (mounted) setState(() => _shortcuts = result);
  }

  void _openTarget(SmartCommandResult result) {
    final page = switch (result.target) {
      SmartCommandTarget.news => const HaberlerSayfasi(),
      SmartCommandTarget.opportunities => const FirsatlarSayfasi(),
      SmartCommandTarget.weather => const HavaMerkeziSayfasi(),
      SmartCommandTarget.trend ||
      SmartCommandTarget.savedAnalyses => TrendTahminiSayfasi(
        initialQuery: result.targetQuery,
        autoAnalyze: result.targetQuery != null,
      ),
      SmartCommandTarget.home => null,
      SmartCommandTarget.none => null,
    };
    if (result.target == SmartCommandTarget.home) {
      Navigator.of(context).pop();
    } else if (page != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Akıllı Kısayollar'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reorder,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: _execute,
            decoration: InputDecoration(
              hintText: 'Altın bugün ne kadar?',
              prefixIcon: const Icon(Icons.auto_awesome_rounded),
              suffixIcon: IconButton(
                onPressed: _executing ? null : _execute,
                icon: _executing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _shortcuts
                .map(
                  (item) => ActionChip(
                    label: Text(item.label),
                    onPressed: () {
                      _controller.text = item.command;
                      _execute(item.command);
                    },
                  ),
                )
                .toList(),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(result: _result!, onOpen: () => _openTarget(_result!)),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onOpen});

  final SmartCommandResult result;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final date = result.updatedAt?.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Kaynak: ${result.source}',
              style: const TextStyle(color: Colors.white60),
            ),
            if (date != null)
              Text(
                'Güncelleme: ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white54),
              ),
            if (result.target != SmartCommandTarget.none) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('İlgili sayfayı aç'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
