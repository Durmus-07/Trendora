import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendora_app/trendora_tanitim_turu_sayfasi.dart';

void main() {
  testWidgets('tanitim turu tum deneme adimlarini tamamlar', (tester) async {
    var tamamlandi = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TrendoraTanitimTuruSayfasi(
          onCompleted: () async {
            tamamlandi = true;
          },
        ),
      ),
    );

    expect(find.text('Dünya Taranıyor'), findsOneWidget);

    for (final eylem in [
      'Taramayı dene',
      'Örnek aramayı çalıştır',
      'Örnek haberi aç',
      'Fırsatı incele',
      'Analiz örneğini gör',
      'Örnek bildirimi dene',
    ]) {
      await tester.tap(find.text(eylem));
      await tester.pumpAndSettle();
    }

    expect(tamamlandi, isTrue);
  });

  testWidgets('turun ornek veriyi degistirmedigi aciklanir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrendoraTanitimTuruSayfasi(onCompleted: () async {}),
      ),
    );

    expect(
      find.textContaining('favorilerini, takiplerini veya bildirim ayarlarını'),
      findsOneWidget,
    );
  });
}
