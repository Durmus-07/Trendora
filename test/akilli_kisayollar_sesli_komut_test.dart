import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/akilli_kisayollar_sayfasi.dart';
import 'package:trendora_app/core/shortcuts/smart_command_service.dart';
import 'package:trendora_app/core/shortcuts/speech_input_service.dart';

void main() {
  testWidgets('microphone never starts without a user tap', (tester) async {
    final speech = _FakeSpeechInput();
    final setup = await _setup(speech);

    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();

    expect(speech.startCount, 0);
    expect(find.byTooltip('Sesli komut'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('recognized text stays editable and is never auto executed', (
    tester,
  ) async {
    final speech = _FakeSpeechInput();
    final source = _FakeCommandSource();
    final setup = await _setup(speech, source: source);

    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sesli komut'));
    await tester.pump();

    expect(speech.startCount, 1);
    expect(find.textContaining('Dinleniyor'), findsOneWidget);
    speech.emit('Altın ne kadar?', isFinal: true);
    await tester.pump();

    expect(_field(tester).controller?.text, 'Altın ne kadar?');
    expect(source.calls, 0);
    await tester.enterText(find.byType(TextField), 'Altın bugün ne kadar?');
    expect(_field(tester).controller?.text, 'Altın bugün ne kadar?');
    expect(source.calls, 0);

    await tester.tap(find.byTooltip('Komutu çalıştır'));
    await tester.pumpAndSettle();

    expect(source.calls, 1);
    expect(find.textContaining('Gram Altın'), findsOneWidget);
    expect(
      setup.preferences.getKeys().any(
        (key) => '${setup.preferences.get(key)}'.contains('Altın bugün'),
      ),
      isFalse,
    );
  });

  testWidgets('permission denial keeps typed commands available', (
    tester,
  ) async {
    final speech = _FakeSpeechInput(
      startResult: SpeechInputStartResult.permissionDenied,
    );
    final source = _FakeCommandSource();
    final setup = await _setup(speech, source: source);

    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sesli komut'));
    await tester.pump();

    expect(find.textContaining('Mikrofon izni verilmedi'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Altın bugün ne kadar?');
    await tester.tap(find.byTooltip('Komutu çalıştır'));
    await tester.pumpAndSettle();

    expect(source.calls, 1);
    expect(find.textContaining('Gram Altın'), findsOneWidget);
  });

  testWidgets('stop keeps transcript while cancel restores previous text', (
    tester,
  ) async {
    final speech = _FakeSpeechInput();
    final setup = await _setup(speech);

    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Önceki metin');
    await tester.tap(find.byTooltip('Sesli komut'));
    await tester.pump();
    speech.emit('Geçici tanınan metin');
    await tester.pump();
    await tester.tap(find.text('Durdur'));
    await tester.pump();

    expect(speech.stopCount, 1);
    expect(_field(tester).controller?.text, 'Geçici tanınan metin');

    await tester.tap(find.byTooltip('Sesli komut'));
    await tester.pump();
    speech.emit('İptal edilecek metin');
    await tester.pump();
    await tester.tap(find.text('İptal'));
    await tester.pump();

    expect(speech.cancelCount, 1);
    expect(_field(tester).controller?.text, 'Geçici tanınan metin');
  });

  testWidgets('empty speech is ignored and narrow layout does not overflow', (
    tester,
  ) async {
    final speech = _FakeSpeechInput();
    final source = _FakeCommandSource();
    final setup = await _setup(speech, source: source);
    await tester.binding.setSurfaceSize(const Size(288, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sesli komut'));
    await tester.pump();
    speech.emit('   ', isFinal: true);
    await tester.pump();

    expect(source.calls, 0);
    expect(_field(tester).controller?.text, isEmpty);
    expect(find.textContaining('Hiçbir komut çalıştırılmadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lifecycle change and dispose end active listening', (
    tester,
  ) async {
    final speech = _FakeSpeechInput();
    final setup = await _setup(speech);

    await tester.pumpWidget(setup.app);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sesli komut'));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(speech.cancelCount, 1);
    expect(speech.isListening, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(speech.startCount, 1);
    expect(speech.isListening, isFalse);

    await tester.tap(find.byTooltip('Sesli komut'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(speech.startCount, 2);
    expect(speech.disposeCount, 1);
    expect(speech.wasListeningAtDispose, isTrue);
    expect(speech.isListening, isFalse);
  });
}

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

Future<_TestSetup> _setup(
  _FakeSpeechInput speech, {
  _FakeCommandSource? source,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final commandSource = source ?? _FakeCommandSource();
  final runtime = SmartCommandRuntime(
    userId: 'guest:voice-test',
    service: SmartCommandService(dataSource: commandSource),
    preferences: preferences,
  );
  return _TestSetup(
    preferences: preferences,
    app: MaterialApp(
      home: AkilliKisayollarSayfasi(
        speechInput: speech,
        runtimeBuilder: () async => runtime,
      ),
    ),
  );
}

class _TestSetup {
  const _TestSetup({required this.preferences, required this.app});

  final SharedPreferences preferences;
  final Widget app;
}

class _FakeSpeechInput implements SpeechInputService {
  _FakeSpeechInput({this.startResult = SpeechInputStartResult.started});

  final SpeechInputStartResult startResult;
  SpeechTranscriptCallback? _onTranscript;
  SpeechListeningCallback? _onListeningChanged;
  bool _listening = false;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  int disposeCount = 0;
  bool wasListeningAtDispose = false;

  @override
  bool get isListening => _listening;

  @override
  Future<SpeechInputStartResult> start({
    required SpeechTranscriptCallback onTranscript,
    required SpeechListeningCallback onListeningChanged,
    required SpeechFailureCallback onFailure,
  }) async {
    startCount++;
    _onTranscript = onTranscript;
    _onListeningChanged = onListeningChanged;
    if (startResult == SpeechInputStartResult.started) {
      _listening = true;
      onListeningChanged(true);
    }
    return startResult;
  }

  void emit(String text, {bool isFinal = false}) {
    _onTranscript?.call(text, isFinal);
    if (isFinal) {
      _listening = false;
      _onListeningChanged?.call(false);
    }
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _listening = false;
    _onListeningChanged?.call(false);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    _listening = false;
    _onListeningChanged?.call(false);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    wasListeningAtDispose = _listening;
    _listening = false;
    _onTranscript = null;
    _onListeningChanged = null;
  }
}

class _FakeCommandSource implements SmartCommandDataSource {
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> marketBoard() async {
    calls++;
    return [
      {
        'symbol': 'XAU',
        'label': 'Gram Altın',
        'price': 4200,
        'changePercent': 1,
        'source': 'Test Piyasa',
        'updatedAt': '2026-07-28T10:00:00Z',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> news() async {
    calls++;
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> opportunities() async {
    calls++;
    return const [];
  }

  @override
  Future<int> savedAnalysisCount() async => 0;

  @override
  Future<Set<String>> trackedSymbols() async => {};

  @override
  Future<({String description, String location, double? temperature})?>
  weather() async => null;
}
