// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:posprint_kit_example/main.dart';

void main() {
  testWidgets('Verify Example Test App renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // OLD:
    // expect(
    //   find.byWidgetPredicate(
    //     (Widget widget) =>
    //         widget is Text && widget.data!.startsWith('Running on:'),
    //   ),
    //   findsOneWidget,
    // );
    // OLD:
    // expect(find.text('POS Print Kit Test Code'), findsOneWidget);
    // expect(find.text('Preview'), findsOneWidget);
    // expect(find.text('WiFi Print'), findsOneWidget);
    expect(find.text('POS Print Kit Test Code'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('WiFi Print'), findsOneWidget);
    expect(find.text('Bluetooth'), findsOneWidget);
    expect(find.text('USB'), findsOneWidget);
    expect(find.text('Virtual Test'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);

    // Switch to Bluetooth tab
    await tester.tap(find.text('Bluetooth'));
    await tester.pumpAndSettle();
    expect(find.text('Bluetooth Thermal Printing (SPP)'), findsOneWidget);
    expect(find.text('Scan Paired Bluetooth Devices'), findsOneWidget);
    expect(find.text('Select Paired Bluetooth Device'), findsOneWidget);

    // Switch to USB tab
    await tester.tap(find.text('USB'));
    await tester.pumpAndSettle();
    expect(find.text('USB Thermal Printing (OTG / Direct)'), findsOneWidget);
    expect(find.text('Scan Connected USB Devices'), findsOneWidget);

    // Switch to Virtual Test tab
    await tester.tap(find.text('Virtual Test'));
    await tester.pumpAndSettle();
    expect(find.text('Run Virtual Print Test'), findsOneWidget);

    // Switch to Doctor tab
    await tester.tap(find.text('Doctor'));
    await tester.pumpAndSettle();
    expect(find.text('Environment & Permissions Doctor'), findsOneWidget);
  });
}
