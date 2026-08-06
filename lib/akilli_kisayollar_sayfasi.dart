import 'dart:async';

import 'package:flutter/material.dart';

import 'core/shortcuts/smart_command_service.dart';
import 'core/shortcuts/smart_shortcut_store.dart';
import 'core/shortcuts/speech_input_service.dart';
import 'firsatlar_sayfasi.dart';
import 'haberler_sayfasi.dart';
import 'hava_merkezi_sayfasi.dart';
import 'trend_tahmini_sayfasi.dart';
import 'trendora_ic_tarayıcı_sayfasi.dart';

class AkilliKisayollarSayfasi extends StatefulWidget {
  const AkilliKisayollarSayfasi({
    super.key,
    this.initialCommand,
    this.speechInput,
    this.runtimeBuilder,
  });

  final String? initialCommand;
  final SpeechInputService? speechInput;
  final Future<SmartCommandRuntime> Function()? runtimeBuilder;

  @override
  State<AkilliKisayollarSayfasi> createState() =>
      _AkilliKisayollarSayfasiState();
}

class _AkilliKisayollarSayfasiState extends State<AkilliKisayollarSayfasi>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();
  late final SpeechInputService _speechInput;
  SmartCommandRuntime? _runtime;
  List<SmartShortcutDefinition> _shortcuts = const [];
  SmartCommandResult? _result;
  bool _loading = true;
  bool _executing = false;
  bool _speechStarting = false;
  bool _speechListening = false;
  bool _receivedSpeechText = false;
  String _textBeforeSpeech = '';
  String? _speechMessage;
  int _executionId = 0;

  bool get _speechBusy =>
      _speechStarting || _speechListening || _speechInput.isListening;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speechInput = widget.speechInput ?? DeviceSpeechInputService();
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_speechInput.dispose());
    _queryFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_speechListening || _speechInput.isListening)) {
      unawaited(_cancelSpeech());
    }
  }

  Future<void> _initialize() async {
    try {
      final runtime =
          await (widget.runtimeBuilder?.call() ?? SmartCommandRuntime.create());
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
    if (command.isEmpty || runtime == null || _speechBusy) return;
    final executionId = ++_executionId;
    _queryFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _executing = true;
      _speechMessage = null;
    });
    final result = await runtime.service.execute(command);
    if (!mounted || executionId != _executionId) return;
    setState(() {
      _result = result;
      _executing = false;
    });
    _queryFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _reorder() async {
    if (_speechBusy) await _cancelSpeech();
    if (!mounted) return;
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

  Future<void> _openTarget(SmartCommandResult result) async {
    if (_speechBusy) await _cancelSpeech();
    if (!mounted) return;
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

  Future<void> _startSpeech() async {
    if (_speechBusy || _executing) return;
    _textBeforeSpeech = _controller.text;
    _receivedSpeechText = false;
    setState(() {
      _speechStarting = true;
      _speechMessage = 'Mikrofon izni ve konuşma hizmeti hazırlanıyor…';
    });
    final result = await _speechInput.start(
      onTranscript: _handleTranscript,
      onListeningChanged: _handleListeningChanged,
      onFailure: _handleSpeechFailure,
    );
    if (!mounted) {
      if (result == SpeechInputStartResult.started) {
        await _speechInput.cancel();
      }
      return;
    }
    setState(() {
      _speechStarting = false;
      switch (result) {
        case SpeechInputStartResult.started:
          _speechListening = true;
          _speechMessage = 'Dinleniyor… Konuşmayı bitirince durdurabilirsin.';
        case SpeechInputStartResult.permissionDenied:
          _speechListening = false;
          _speechMessage =
              'Mikrofon izni verilmedi. Komutunu yazarak kullanmaya devam edebilirsin.';
        case SpeechInputStartResult.unavailable:
          _speechListening = false;
          _speechMessage =
              'Bu cihazda konuşma tanıma kullanılamıyor. Metin girişi kullanılabilir.';
        case SpeechInputStartResult.failed:
          _speechListening = false;
          _speechMessage =
              'Konuşma anlaşılamadı. Metin girişiyle devam edebilirsin.';
      }
    });
  }

  Future<void> _stopSpeech() async {
    if (!_speechBusy && !_speechInput.isListening) return;
    await _speechInput.stop();
    if (!mounted) return;
    setState(() {
      _speechStarting = false;
      _speechListening = false;
      _speechMessage = _receivedSpeechText
          ? 'Tanınan metni düzenleyip komutu çalıştırabilirsin.'
          : 'Konuşma algılanamadı. Metin girişiyle devam edebilirsin.';
    });
  }

  Future<void> _cancelSpeech() async {
    await _speechInput.cancel();
    if (!mounted) return;
    _controller.value = TextEditingValue(
      text: _textBeforeSpeech,
      selection: TextSelection.collapsed(offset: _textBeforeSpeech.length),
    );
    setState(() {
      _speechStarting = false;
      _speechListening = false;
      _receivedSpeechText = false;
      _speechMessage = 'Dinleme iptal edildi. Metin girişi kullanılabilir.';
    });
  }

  void _handleTranscript(String text, bool isFinal) {
    if (!mounted) return;
    final recognized = text.trim();
    if (recognized.isNotEmpty) {
      _receivedSpeechText = true;
      _controller.value = TextEditingValue(
        text: recognized,
        selection: TextSelection.collapsed(offset: recognized.length),
      );
    }
    if (isFinal) {
      if (recognized.isEmpty) {
        _receivedSpeechText = false;
        _controller.value = TextEditingValue(
          text: _textBeforeSpeech,
          selection: TextSelection.collapsed(offset: _textBeforeSpeech.length),
        );
      }
      setState(() {
        _speechStarting = false;
        _speechListening = false;
        _speechMessage = recognized.isEmpty
            ? 'Konuşma algılanamadı. Hiçbir komut çalıştırılmadı.'
            : 'Tanınan metni düzenleyip komutu çalıştırabilirsin.';
      });
    } else {
      setState(() {});
    }
  }

  void _handleListeningChanged(bool listening) {
    if (!mounted) return;
    setState(() {
      _speechStarting = false;
      _speechListening = listening;
      if (listening) {
        _speechMessage = 'Dinleniyor… Konuşmayı bitirince durdurabilirsin.';
      } else if (_speechMessage?.startsWith('Dinleniyor') == true) {
        _speechMessage = _receivedSpeechText
            ? 'Tanınan metni düzenleyip komutu çalıştırabilirsin.'
            : 'Konuşma algılanamadı. Hiçbir komut çalıştırılmadı.';
      }
    });
  }

  void _handleSpeechFailure(SpeechInputStartResult failure) {
    if (!mounted) return;
    setState(() {
      _speechStarting = false;
      _speechListening = false;
      _speechMessage = failure == SpeechInputStartResult.permissionDenied
          ? 'Mikrofon izni verilmedi. Komutunu yazarak kullanmaya devam edebilirsin.'
          : 'Konuşma tanıma tamamlanamadı. Metin girişi kullanılabilir.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Trendora Arama Motoru'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reorder,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Trendora içindeki haberleri, fırsatları, piyasaları ve analizleri arayın veya genel bir soru sorun.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _queryFocusNode,
            autofocus: false,
            onTapOutside: (_) => _queryFocusNode.unfocus(),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              if (!_speechBusy) _execute(value);
            },
            decoration: InputDecoration(
              hintText: 'Bir şey yazın veya sorun…',
              prefixIcon: const Icon(Icons.auto_awesome_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: _speechListening
                        ? 'Sesli komutu durdur'
                        : 'Sesli komutu başlat',
                    child: IconButton(
                      tooltip: _speechListening
                          ? 'Dinlemeyi durdur'
                          : 'Sesli komut',
                      onPressed: _executing || _speechStarting
                          ? null
                          : _speechListening
                          ? _stopSpeech
                          : _startSpeech,
                      icon: Icon(
                        _speechListening
                            ? Icons.stop_circle_outlined
                            : Icons.mic_none_rounded,
                        color: _speechListening ? Colors.redAccent : null,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Komutu çalıştır',
                    onPressed: _speechBusy ? null : _execute,
                    icon: _executing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (_speechMessage != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              label: _speechMessage,
              child: Container(
                key: const ValueKey('speech-status'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101D2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _speechListening
                        ? Colors.redAccent.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      _speechListening
                          ? Icons.mic_rounded
                          : Icons.info_outline_rounded,
                      color: _speechListening
                          ? Colors.redAccent
                          : Colors.white70,
                      size: 19,
                    ),
                    Text(
                      _speechMessage!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (_speechListening) ...[
                      OutlinedButton.icon(
                        onPressed: _stopSpeech,
                        icon: const Icon(Icons.stop_rounded, size: 17),
                        label: const Text('Durdur'),
                      ),
                      TextButton(
                        onPressed: _cancelSpeech,
                        child: const Text('İptal'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _shortcuts
                .map(
                  (item) => ActionChip(
                    label: Text(item.label),
                    onPressed: _speechBusy
                        ? null
                        : () {
                            _controller.text = item.command;
                            _execute(item.command);
                          },
                  ),
                )
                .toList(),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(
              result: _result!,
              onOpen: () {
                _openTarget(_result!);
              },
              onSelectAsset: (symbol) {
                final suffix =
                    _result!.intent == SmartCommandIntent.marketAnalysis
                    ? 'analiz et'
                    : 'kaç TL?';
                final command = '$symbol $suffix';
                _controller.text = command;
                _execute(command);
              },
              onOpenWebResult: (item) {
                final url = '${item['url'] ?? ''}'.trim();
                if (url.isEmpty) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrendoraIcTarayiciSayfasi(
                      url: url,
                      title: '${item['title'] ?? 'Trendora'}',
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onOpen,
    required this.onSelectAsset,
    required this.onOpenWebResult,
  });

  final SmartCommandResult result;
  final VoidCallback onOpen;
  final ValueChanged<String> onSelectAsset;
  final ValueChanged<Map<String, dynamic>> onOpenWebResult;

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
            if (result.cards.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...result.cards
                  .take(5)
                  .map(
                    (item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        result.target == SmartCommandTarget.news
                            ? Icons.article_outlined
                            : result.target == SmartCommandTarget.opportunities
                            ? Icons.local_offer_outlined
                            : Icons.bookmark_outline,
                      ),
                      title: Text(
                        '${item['title'] ?? item['name'] ?? 'Sonuç'}',
                      ),
                      subtitle: Text(
                        [
                          '${item['source'] ?? item['store'] ?? ''}',
                          '${item['snippet'] ?? ''}',
                        ].where((value) => value.trim().isNotEmpty).join(' • '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: '${item['url'] ?? ''}'.trim().isNotEmpty
                          ? const Icon(Icons.chevron_right_rounded)
                          : null,
                      onTap: '${item['url'] ?? ''}'.trim().isNotEmpty
                          ? () => onOpenWebResult(item)
                          : '${item['canonicalSymbol'] ?? ''}'.isEmpty
                          ? null
                          : () => onSelectAsset('${item['canonicalSymbol']}'),
                    ),
                  ),
            ],
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
                label: Text(result.buttonLabel ?? 'İlgili sayfayı aç'),
              ),
            ],
            if (result.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Öneriler: ${result.suggestions.join(' • ')}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
