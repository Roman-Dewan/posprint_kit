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

    test('realtime cash drawer pulses emit DLE DC4 1 m t (works without paper)', () {
      expect(Commands.realtimeCashDrawerPin2, [0x10, 0x14, 0x01, 0x00, 0x01]);
      expect(Commands.realtimeCashDrawerPin5, [0x10, 0x14, 0x01, 0x01, 0x01]);
      expect(Commands.sunmiCashDrawer, [0x10, 0x14, 0x00, 0x00, 0x00]);
      expect(Commands.starCashDrawer, [0x07]);
      expect(Commands.realtimeCashDrawerPulse(pin5: false, duration: 2), [0x10, 0x14, 0x01, 0x00, 0x02]);
      expect(Commands.realtimeCashDrawerPulse(pin5: true, duration: 1), [0x10, 0x14, 0x01, 0x01, 0x01]);
    });

    test('openCashDrawerSequence includes real-time and standard pulses for paper-out reliability', () {
      final seqPin2And5 = Commands.openCashDrawerSequence(pin: CashDrawerPin.pin2And5);
      // Contains DLE DC4 real-time pulses for both pin 2 and pin 5
      expect(seqPin2And5, containsAllInOrder([0x10, 0x14, 0x01, 0x00, 0x01]));
      expect(seqPin2And5, containsAllInOrder([0x10, 0x14, 0x01, 0x01, 0x01]));
      // Contains Sunmi real-time pulse
      expect(seqPin2And5, containsAllInOrder([0x10, 0x14, 0x00, 0x00, 0x00]));
      // Contains standard ESC p pulses
      expect(seqPin2And5, containsAllInOrder([0x1B, 0x70, 0x00, 0x32, 0xFA]));
      expect(seqPin2And5, containsAllInOrder([0x1B, 0x70, 0x01, 0x32, 0xFA]));
      // Contains Star BEL pulse
      expect(seqPin2And5.last, 0x07);

      final seqPin2 = Commands.openCashDrawerSequence(pin: CashDrawerPin.pin2);
      expect(seqPin2, containsAllInOrder([0x10, 0x14, 0x01, 0x00, 0x01]));
      expect(seqPin2.contains(0x07), isTrue);

      final seqPin5 = Commands.openCashDrawerSequence(pin: CashDrawerPin.pin5);
      expect(seqPin5, containsAllInOrder([0x10, 0x14, 0x01, 0x01, 0x01]));
    });

    test('selectCodePage emits ESC t n', () {
      expect(
          Commands.selectCodePage(0), Uint8List.fromList([0x1B, 0x74, 0x00]));
      expect(
          Commands.selectCodePage(19), Uint8List.fromList([0x1B, 0x74, 0x13]));
    });

    test('QR code sequence matches ESC/POS specification', () {
      expect(Commands.qrSelectModel2, [
        0x1D,
        0x28,
        0x6B,
        0x04,
        0x00,
        0x31,
        0x41,
        0x32,
        0x00,
      ]);
      expect(Commands.qrModuleSize(6), [
        0x1D,
        0x28,
        0x6B,
        0x03,
        0x00,
        0x31,
        0x43,
        0x06,
      ]);
      expect(Commands.qrErrorCorrection(0x31), [
        0x1D,
        0x28,
        0x6B,
        0x03,
        0x00,
        0x31,
        0x45,
        0x31,
      ]);
      final store = Commands.qrStoreData([0x48, 0x49]); // "HI"
      expect(store, [
        0x1D,
        0x28,
        0x6B,
        0x05,
        0x00,
        0x31,
        0x50,
        0x30,
        0x48,
        0x49,
      ]);
      expect(Commands.qrPrint, [
        0x1D,
        0x28,
        0x6B,
        0x03,
        0x00,
        0x31,
        0x51,
        0x30,
      ]);
    });

    test('rasterHeader emits GS v 0', () {
      // 576 dots / 8 = 72 bytes wide (0x48, 0x00), 40 dots high (0x28, 0x00)
      final header = Commands.rasterHeader(bytesPerLine: 72, heightDots: 40);
      expect(header, [0x1D, 0x76, 0x30, 0x00, 0x48, 0x00, 0x28, 0x00]);
    });

    test('rasterLine and rasterDashedLine emit full width thermal divider bands', () {
      final solid = Commands.rasterLine(dotsWidth: 576, heightDots: 2);
      expect(solid.length, 8 + (72 * 2));
      expect(solid.sublist(0, 4), [0x1D, 0x76, 0x30, 0x00]);
      expect(solid.sublist(8).every((b) => b == 0xFF), isTrue);

      final dashed = Commands.rasterDashedLine(dotsWidth: 576, heightDots: 2);
      expect(dashed.length, 8 + (72 * 2));
      expect(dashed.sublist(0, 4), [0x1D, 0x76, 0x30, 0x00]);
      expect(dashed.sublist(8).every((b) => b == 0xF0), isTrue);
    });

    test('formatCode128Data ensures Code 128 data starts with code set B {B', () {
      final raw = [0x31, 0x30, 0x34, 0x32]; // "1042"
      final formatted = Commands.formatCode128Data(raw);
      expect(formatted, [0x7B, 0x42, 0x31, 0x30, 0x34, 0x32]);

      // If already prefixed with {B, does not double-prefix
      final alreadyB = [0x7B, 0x42, 0x31, 0x32];
      expect(Commands.formatCode128Data(alreadyB), [0x7B, 0x42, 0x31, 0x32]);

      // If already prefixed with {A or {C, preserves it
      final alreadyA = [0x7B, 0x41, 0x31, 0x32];
      expect(Commands.formatCode128Data(alreadyA), [0x7B, 0x41, 0x31, 0x32]);
      final alreadyC = [0x7B, 0x43, 0x12, 0x34];
      expect(Commands.formatCode128Data(alreadyC), [0x7B, 0x43, 0x12, 0x34]);
    });

    test('code128 emits GS k 73 with {B prefixed payload', () {
      final cmd = Commands.code128([0x31, 0x30, 0x34, 0x32]); // "1042" -> length 6
      expect(cmd, [
        0x1D, 0x6B, 73, 6,
        0x7B, 0x42, 0x31, 0x30, 0x34, 0x32,
      ]);
    });
  });
}
