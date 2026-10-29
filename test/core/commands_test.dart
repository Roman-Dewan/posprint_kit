import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/src/core/commands.dart';

void main() {
  group('Commands byte constants (Golden Bytes)', () {
    test('hardware init is ESC @ (0x1B 0x40)', () {
      expect(Commands.init, [0x1B, 0x40]);
    });

    test('feedLines emits ESC d n', () {
      expect(Commands.feedLines(3), Uint8List.fromList([0x1B, 0x64, 0x03]));
    });

    test('alignment commands emit ESC a 0/1/2', () {
      expect(Commands.alignLeft, [0x1B, 0x61, 0x00]);
      expect(Commands.alignCenter, [0x1B, 0x61, 0x01]);
      expect(Commands.alignRight, [0x1B, 0x61, 0x02]);
    });

    test('bold commands emit ESC E 0/1', () {
      expect(Commands.boldOff, [0x1B, 0x45, 0x00]);
      expect(Commands.boldOn, [0x1B, 0x45, 0x01]);
    });

    test('underline commands emit ESC - 0/1/2', () {
      expect(Commands.underlineOff, [0x1B, 0x2D, 0x00]);
      expect(Commands.underlineThin, [0x1B, 0x2D, 0x01]);
      expect(Commands.underlineThick, [0x1B, 0x2D, 0x02]);
    });

    test('size commands emit GS ! n', () {
      expect(Commands.sizeNormal, [0x1D, 0x21, 0x00]);
      expect(Commands.sizeDoubleWidth, [0x1D, 0x21, 0x10]);
      expect(Commands.sizeDoubleHeight, [0x1D, 0x21, 0x01]);
      expect(Commands.sizeDouble, [0x1D, 0x21, 0x11]);
    });

    test('paper cut commands emit GS V 0/1', () {
      expect(Commands.cutFull, [0x1D, 0x56, 0x00]);
      expect(Commands.cutPartial, [0x1D, 0x56, 0x01]);
    });

    test('cash drawer pulses emit ESC p m t1 t2', () {
      expect(Commands.cashDrawerPin2, [0x1B, 0x70, 0x00, 0x19, 0xFA]);
      expect(Commands.cashDrawerPin5, [0x1B, 0x70, 0x01, 0x19, 0xFA]);
    });

    test('selectCodePage emits ESC t n', () {
      expect(Commands.selectCodePage(0), Uint8List.fromList([0x1B, 0x74, 0x00]));
      expect(Commands.selectCodePage(19), Uint8List.fromList([0x1B, 0x74, 0x13]));
    });

    test('QR code sequence matches ESC/POS specification', () {
      expect(Commands.qrSelectModel2, [
        0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
      ]);
      expect(Commands.qrModuleSize(6), [
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06,
      ]);
      expect(Commands.qrErrorCorrection(0x31), [
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,
      ]);
      final store = Commands.qrStoreData([0x48, 0x49]); // "HI"
      expect(store, [
        0x1D, 0x28, 0x6B, 0x05, 0x00, 0x31, 0x50, 0x30, 0x48, 0x49,
      ]);
      expect(Commands.qrPrint, [
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
      ]);
    });

    test('rasterHeader emits GS v 0', () {
      // 576 dots / 8 = 72 bytes wide (0x48, 0x00), 40 dots high (0x28, 0x00)
      final header = Commands.rasterHeader(bytesPerLine: 72, heightDots: 40);
      expect(header, [0x1D, 0x76, 0x30, 0x00, 0x48, 0x00, 0x28, 0x00]);
    });
  });
}

