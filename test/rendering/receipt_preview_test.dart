import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/posprint_kit.dart';

void main() {
  group('ReceiptPreview Widget Tests', () {
    testWidgets('renders all receipt ops on screen', (tester) async {
      final receipt = Receipt()
        ..title('THE COFFEE HOUSE')
        ..divider()
        ..row('Caramel Macchiato', '4.75')
        ..row('Croissant x2', '6.00')
        ..divider()
        ..total('TOTAL', '10.75')
        ..qr('https://example.com/receipt/99')
        ..barcode('990012', type: BarcodeType.code128)
        ..feed(1)
        ..cut();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReceiptPreview(
                receipt: receipt,
                profile: PrinterProfile.generic80,
              ),
            ),
          ),
        ),
      );

      // Verify text elements are rendered on screen
      expect(find.text('THE COFFEE HOUSE'), findsOneWidget);
      expect(find.text('Caramel Macchiato'), findsOneWidget);
      expect(find.text('4.75'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('10.75'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
      expect(find.byIcon(Icons.content_cut), findsOneWidget);
    });
  });
}

