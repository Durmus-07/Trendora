import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/core/personalization/personalization_service.dart';
import 'package:trendora_app/core/personalization/personalization_storage.dart';
import 'package:trendora_app/ilgi_alanlari_sayfasi.dart';

void main() {
  testWidgets('allows multiple selections and persists them', (tester) async {
    final memory = _MemoryStore(
      strings: {'trendora_anonymous_user_id_v1': 'guest:widget'},
    );
    await tester.pumpWidget(
      MaterialApp(home: IlgiAlanlariSayfasi(service: _service(memory))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Teknoloji'));
    await tester.tap(find.text('Spor'));
    await tester.tap(find.text('Tercihleri Kaydet'));
    await tester.pumpAndSettle();

    final restored = await _service(memory).initialize();
    expect(restored.interests, {'technology', 'sports'});
    expect(restored.personalizationEnabled, isTrue);
  });

  testWidgets('can be skipped without selecting an interest', (tester) async {
    final memory = _MemoryStore(
      strings: {'trendora_anonymous_user_id_v1': 'guest:skip'},
    );
    await tester.pumpWidget(
      MaterialApp(home: IlgiAlanlariSayfasi(service: _service(memory))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Şimdi Değil'), findsOneWidget);
    await tester.tap(find.text('Şimdi Değil'));
    await tester.pumpAndSettle();

    final restored = await _service(memory).initialize();
    expect(restored.interests, isEmpty);
    expect(restored.personalizationEnabled, isFalse);
  });

  testWidgets('loads existing choices without forcing a new flow', (
    tester,
  ) async {
    final memory = _MemoryStore(
      strings: {'trendora_anonymous_user_id_v1': 'guest:existing'},
    );
    final service = _service(memory);
    await service.initialize();
    await service.updateInterests({'economy'});
    await service.setPersonalizationEnabled(true);

    await tester.pumpWidget(
      MaterialApp(home: IlgiAlanlariSayfasi(service: _service(memory))),
    );
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('economy')),
    );
    expect(chip.selected, isTrue);
    expect(find.text('Şimdi Değil'), findsOneWidget);
  });
}

PersonalizationService _service(_MemoryStore memory) {
  return PersonalizationService(
    repository: PersonalizationLocalRepository(memory),
    identityProvider: PersonalizationIdentityProvider(memory),
  );
}

class _MemoryStore implements PersonalizationKeyValueStore {
  _MemoryStore({Map<String, String>? strings}) : strings = {...?strings};

  final Map<String, String> strings;

  @override
  String? getString(String key) => strings[key];

  @override
  List<String>? getStringList(String key) => null;

  @override
  Future<bool> remove(String key) async => strings.remove(key) != null;

  @override
  Future<bool> setString(String key, String value) async {
    strings[key] = value;
    return true;
  }
}
