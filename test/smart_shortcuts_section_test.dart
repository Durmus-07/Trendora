import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendora_app/widgets/smart_shortcuts_section.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home search is shown without prepared examples', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SmartShortcutsSection())),
    );
    await tester.pump();

    final search = find.byType(TextField);
    expect(search, findsOneWidget);
    expect(find.text('Örnek aramalar'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('keyboard search opens the engine with the entered query', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SmartShortcutsSection())),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ASELSAN kaç TL?');
    expect(
      find.byType(EditableText).evaluate().single.widget,
      isA<EditableText>().having(
        (item) => item.focusNode.hasFocus,
        'focus',
        isTrue,
      ),
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Trendora Arama Motoru'), findsOneWidget);
    expect(find.text('ASELSAN kaç TL?'), findsOneWidget);
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .every((item) => !item.focusNode.hasFocus),
      isTrue,
    );
  });

  testWidgets('search button opens the engine and releases keyboard focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SmartShortcutsSection())),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Migros fırsatları');
    await tester.tap(find.byTooltip('Ara'));
    await tester.pumpAndSettle();

    expect(find.text('Migros fırsatları'), findsOneWidget);
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .every((item) => !item.focusNode.hasFocus),
      isTrue,
    );
  });
}
