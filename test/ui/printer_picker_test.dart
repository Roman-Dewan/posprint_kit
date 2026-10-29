import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/posprint_kit.dart';

void main() {
  group('PrinterPicker Widget Tests (DX-9)', () {
    testWidgets('renders transport selectors and triggers callback on save', (tester) async {
      EscposPrinter? selectedPrinter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrinterPicker(
                onPrinterSelected: (p) => selectedPrinter = p,
              ),
            ),
          ),
        ),
      );

      // Verify header and options
      expect(find.text('Select Thermal Printer'), findsOneWidget);
      expect(find.text('WiFi / LAN'), findsOneWidget);
      expect(find.text('Bluetooth'), findsOneWidget);
      expect(find.text('USB OTG'), findsOneWidget);

      // Tap Save & Select
      await tester.tap(find.text('Save & Select'));
      await tester.pump();

      expect(selectedPrinter, isNotNull);
      expect(selectedPrinter?.profile, PrinterProfile.generic80);
    });

    testWidgets('switching to Bluetooth shows Bluetooth address input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrinterPicker(onPrinterSelected: (_) {}),
            ),
          ),
        ),
      );

      // Tap Bluetooth segment
      await tester.tap(find.text('Bluetooth'));
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth MAC Address / Name'), findsOneWidget);
    });
  });
}

