import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/posprint_kit.dart';

void main() {
  group('TsplLabelPreview Widget Tests', () {
    testWidgets('renders preview with elements and dimension tags for 40x30 mm', (tester) async {
      final label = TsplLabel(size: TsplSize.size40x30)
        ..text('FRESH APPLES', x: 20, y: 20)
        ..textRaster('টাটকা আপেল', x: 20, y: 55, fontSize: 16, languageTag: 'bn')
        ..barcode('12345678', x: 20, y: 90, height: 40)
        ..qr('https://example.com', x: 200, y: 90, size: 4)
        ..box(x: 5, y: 5, endX: 315, endY: 235, thickness: 2)
        ..bar(x: 10, y: 48, width: 300, height: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TsplLabelPreview(label: label),
            ),
          ),
        ),
      );

      expect(find.textContaining('40 × 30 mm'), findsOneWidget);
      expect(find.textContaining('320 × 240 dots'), findsOneWidget);
      expect(find.text('FRESH APPLES'), findsOneWidget);
      expect(find.text('টাটকা আপেল'), findsOneWidget);
      expect(find.text('12345678'), findsOneWidget);
    });

    testWidgets('renders cleanly for compact 20x30 mm and wide 60x40 mm labels', (tester) async {
      final s2030 = TsplLabel(size: TsplSize.size20x30)
        ..text('TAG-01', x: 10, y: 10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TsplLabelPreview(label: s2030),
          ),
        ),
      );

      expect(find.textContaining('20 × 30 mm'), findsOneWidget);
      expect(find.text('TAG-01'), findsOneWidget);

      final s6040 = TsplLabel(size: TsplSize.size60x40)
        ..text('SHIPPING LABEL', x: 10, y: 10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TsplLabelPreview(label: s6040),
          ),
        ),
      );

      expect(find.textContaining('60 × 40 mm'), findsOneWidget);
      expect(find.text('SHIPPING LABEL'), findsOneWidget);
    });
  });
}
