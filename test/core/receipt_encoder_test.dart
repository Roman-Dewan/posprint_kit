import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/src/core/code_pages.dart';
import 'package:posprint_kit/src/core/commands.dart';
import 'package:posprint_kit/src/core/ops.dart';
import 'package:posprint_kit/src/core/printer_profile.dart';
import 'package:posprint_kit/src/core/receipt.dart';
import 'package:posprint_kit/src/core/receipt_encoder.dart';

void main() {
  group('ReceiptEncoder Golden-Bytes Tests', () {
    test('text with bold, size and alignment emits matching ESC/POS commands', () async {
      final receipt = Receipt()
        ..text('Centered Bold', align: PosAlign.center, bold: true, size: TextSize.doubleSize);

      final bytes = await encodeForTest(receipt);

      // Default CP437 select: ESC t 0 (1B 74 00)
      // Align center: ESC a 1 (1B 61 01)
      // Bold on: ESC E 1 (1B 45 01)
      // Size double: GS ! 17 (1D 21 11)
      // Text: "Centered Bold\n"
      // Cleanup: bold off (1B 45 00), size normal (1D 21 00), align left (1B 61 00)
      final expected = <int>[
        0x1B, 0x74, 0x00,
        0x1B, 0x61, 0x01,
        0x1B, 0x45, 0x01,
        0x1D, 0x21, 0x11,
        ...ascii.encode('Centered Bold\n'),
        0x1B, 0x45, 0x00,
        0x1D, 0x21, 0x00,
        0x1B, 0x61, 0x00,
      ];

      expect(bytes, expected);
    });

    test('row formats native text with price flush against the right margin', () async {
      final receipt = Receipt()..row('Burger x2', '12.00');

      // 48 columns total for generic80
      // 'Burger x2' = 9 chars, '12.00' = 5 chars -> 34 spaces in between
      final bytes = await encodeForTest(receipt);

      final expectedRow = 'Burger x2${' ' * 34}12.00\n';
      final expected = <int>[
        0x1B, 0x74, 0x00,
        ...ascii.encode(expectedRow),
      ];

      expect(bytes, expected);
    });

    test('divider emits exact column width of characters', () async {
      final receipt = Receipt()..divider();
      final bytes = await encodeForTest(receipt);

      final expectedDivider = '${'-' * 48}\n';
      expect(bytes, [
        0x1B, 0x74, 0x00,
        ...ascii.encode(expectedDivider),
      ]);
    });

    test('cut full and partial emit GS V 0 and GS V 1', () async {
      final receipt = Receipt()
        ..cut(partial: false, feedDots: 0)
        ..cut(partial: true, feedDots: 0);

      final bytes = await encodeForTest(receipt);
      expect(bytes, [
        0x1B, 0x74, 0x00,
        0x1D, 0x56, 0x00, // Full cut
        0x1D, 0x56, 0x01, // Partial cut
      ]);
    });

    test('qr("HI") emits model, size, ecc, store, print matching Skill 4', () async {
      final receipt = Receipt()..qr('HI', size: 6);
      final bytes = await encodeForTest(receipt);

      expect(bytes, [
        0x1B, 0x74, 0x00, // code page init
        0x1B, 0x61, 0x01, // align center
        0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00, // model 2
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06, // module size 6
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31, // error correction M
        0x1D, 0x28, 0x6B, 0x05, 0x00, 0x31, 0x50, 0x30, 0x48, 0x49, // store "HI"
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30, // print
        0x1B, 0x61, 0x00, // reset to align left
      ]);
    });

    test('barcode(code128) emits height, width, hri, and barcode command', () async {
      final receipt = Receipt()..barcode('1042', type: BarcodeType.code128);
      final bytes = await encodeForTest(receipt);

      expect(bytes, [
        0x1B, 0x74, 0x00, // code page init
        0x1B, 0x61, 0x01, // align center
        0x1D, 0x68, 0x40, // height 64 dots (0x40)
        0x1D, 0x77, 0x02, // width 2
        0x1D, 0x48, 0x02, // HRI below
        0x1D, 0x6B, 0x49, 0x04, 0x31, 0x30, 0x34, 0x32, // CODE128 '1042'
        0x1B, 0x61, 0x00, // align left reset
      ]);
    });

    test('cash drawer pulses emit ESC p', () async {
      final receipt = Receipt()
        ..drawer(pin5: false)
        ..drawer(pin5: true);

      final bytes = await encodeForTest(receipt);
      expect(bytes, [
        0x1B, 0x74, 0x00,
        0x1B, 0x70, 0x00, 0x19, 0xFA, // pin 2
        0x1B, 0x70, 0x01, 0x19, 0xFA, // pin 5
      ]);
    });

    test('Latin accented text switches code page when needed', () async {
      // Profile with CP437 and CP858
      const profile = PrinterProfile(
        dotsWidth: 576,
        columnsNormal: 48,
        codePages: [CodePage.cp437, CodePage.cp858],
      );

      // 'Café' has 'é' which is 0x82 in CP437
      final receipt = Receipt()..text('Café');
      final bytes = await encodeForTest(receipt, profile: profile);

      expect(bytes, [
        0x1B, 0x74, 0x00, // select CP437 (ESC t 0)
        0x43, 0x61, 0x66, 0x82, 0x0A, // C, a, f, é (0x82), LF
      ]);
    });

    test('Full receipt test matching Phase 1 realistic check', () async {
      final receipt = Receipt()
        ..title('MY RESTAURANT')
        ..divider()
        ..row('Burger x2', '12.00')
        ..row('Cola x1', '2.00')
        ..divider()
        ..total('TOTAL', '14.00')
        ..qr('https://example.com/order/1042')
        ..feed(1)
        ..cut();

      final bytes = await encodeForTest(receipt, init: true);

      // Starts with ESC @ (1B 40)
      expect(bytes.sublist(0, 2), Commands.init);

      // Contains 'MY RESTAURANT'
      expect(bytes, containsAllInOrder(ascii.encode('MY RESTAURANT')));

      // Contains divider
      expect(bytes, containsAllInOrder(ascii.encode('--------------------------------')));

      // Contains row items
      expect(bytes, containsAllInOrder(ascii.encode('Burger x2')));
      expect(bytes, containsAllInOrder(ascii.encode('12.00')));
      expect(bytes, containsAllInOrder(ascii.encode('Cola x1')));
      expect(bytes, containsAllInOrder(ascii.encode('2.00')));

      // Contains TOTAL
      expect(bytes, containsAllInOrder(ascii.encode('TOTAL')));
      expect(bytes, containsAllInOrder(ascii.encode('14.00')));

      // Contains QR print command
      expect(bytes, containsAllInOrder(Commands.qrPrint));

      // Ends with cut
      expect(bytes, containsAllInOrder(Commands.cutFull));
    });

    test('Receipt.simple template builds expected receipt ops', () {
      final receipt = Receipt.simple(
        title: 'BURGER SHOP',
        items: [('Burger', '8.00'), ('Fries', '3.00')],
        total: '11.00',
        footer: 'Thank you!',
      );

      expect(receipt.ops.length, greaterThanOrEqualTo(8));
      expect(receipt.ops.any((op) => op is TextOp && op.text == 'BURGER SHOP'), isTrue);
      expect(receipt.ops.any((op) => op is RowOp && op.left == 'Burger'), isTrue);
      expect(receipt.ops.any((op) => op is CutOp), isTrue);
    });
  });
}

