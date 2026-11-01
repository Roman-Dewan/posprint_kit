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

    testWidgets('renders multi-column receipt (ColumnsOp) on screen', (tester) async {
      final receipt = Receipt()
        ..title('MULTI-COLUMN POS')
        ..divider()
        ..columns([
          const PosColumn(text: '#', width: 1, align: PosAlign.center),
          const PosColumn(text: 'Item', width: 5),
          const PosColumn(text: 'Qty', width: 1, align: PosAlign.center),
          const PosColumn(text: 'Price', width: 2, align: PosAlign.right),
          const PosColumn(text: 'Total', width: 2, align: PosAlign.right),
        ], bold: true)
        ..divider()
        ..columns([
          const PosColumn(text: '1', width: 1, align: PosAlign.center),
          const PosColumn(text: 'Special Burger', width: 5),
          const PosColumn(text: '2', width: 1, align: PosAlign.center),
          const PosColumn(text: '6.50', width: 2, align: PosAlign.right),
          const PosColumn(text: '13.00', width: 2, align: PosAlign.right),
        ])
        ..divider()
        ..total('TOTAL', '13.00')
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

      expect(find.text('MULTI-COLUMN POS'), findsOneWidget);
      expect(find.text('Special Burger'), findsOneWidget);
      expect(find.text('13.00'), findsNWidgets(2)); // line item total and summary total
      expect(find.text('Price'), findsOneWidget);
    });
  });
}

