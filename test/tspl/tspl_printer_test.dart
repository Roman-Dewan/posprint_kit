import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/advanced.dart';

void main() {
  group('TsplPrinter Facade Unit Tests', () {
    test('prints label using FakeTransport and connects automatically', () async {
      final fake = FakeTransport();
      final printer = TsplPrinter.custom(fake);

      expect(printer.currentState, PosConnectionState.disconnected);

      final label = TsplLabel(size: TsplSize.size40x30)
        ..text('MILK BREAD', x: 20, y: 20)
        ..barcode('998877', x: 20, y: 60, height: 40);

      final result = await printer.print(label);
      expect(result.isOk, isTrue);
      expect(printer.currentState, PosConnectionState.connected);

      final output = utf8.decode(fake.recordedBytes);
      expect(output, contains('SIZE 40 mm, 30 mm\r\n'));
      expect(output, contains('TEXT 20, 20, "3", 0, 1, 1, "MILK BREAD"\r\n'));
      expect(output, contains('BARCODE 20, 60, "128", 40, 1, 0, 2, 2, "998877"\r\n'));
      expect(output, contains('PRINT 1, 1\r\n'));

      await printer.close();
      expect(printer.currentState, PosConnectionState.disconnected);
      fake.dispose();
    });

    test('formFeed sends FORMFEED command', () async {
      final fake = FakeTransport();
      final printer = TsplPrinter.custom(fake);

      final res = await printer.formFeed();
      expect(res.isOk, isTrue);

      final output = utf8.decode(fake.recordedBytes);
      expect(output, equals('FORMFEED\r\n'));

      await printer.close();
      fake.dispose();
    });

    test('calibrate sends GAPDETECT command', () async {
      final fake = FakeTransport();
      final printer = TsplPrinter.custom(fake);

      final res = await printer.calibrate();
      expect(res.isOk, isTrue);

      final output = utf8.decode(fake.recordedBytes);
      expect(output, equals('GAPDETECT\r\n'));

      await printer.close();
      fake.dispose();
    });

    test('cut sends CUT command', () async {
      final fake = FakeTransport();
      final printer = TsplPrinter.custom(fake);

      final res = await printer.cut();
      expect(res.isOk, isTrue);

      final output = utf8.decode(fake.recordedBytes);
      expect(output, equals('CUT\r\n'));

      await printer.close();
      fake.dispose();
    });

    test('chunks large label data according to transport maxChunkSize', () async {
      final fake = FakeTransport(maxChunkSize: 64);
      final printer = TsplPrinter.custom(fake);

      final label = TsplLabel(size: TsplSize.size60x40)
        ..text('A' * 200, x: 10, y: 10);

      final res = await printer.print(label);
      expect(res.isOk, isTrue);

      final output = utf8.decode(fake.recordedBytes);
      expect(output, contains('SIZE 60 mm, 40 mm\r\n'));
      expect(output, contains('A' * 200));

      await printer.close();
      fake.dispose();
    });

    test('surfaces friendly error if connection fails', () async {
      final fake = FakeTransport()
        ..persistentConnectError = PrinterError.connectionFailed(
          host: '192.168.1.100',
          port: 9100,
        );

      final printer = TsplPrinter.custom(fake);
      final label = TsplLabel(size: TsplSize.size30x20)..text('TEST', x: 0, y: 0);

      final res = await printer.print(label, retryDelays: const [Duration(milliseconds: 10)]);
      expect(res.isError, isTrue);
      expect(res.errorOrNull?.code, PrinterErrorCode.connectionFailed);
      expect(res.errorOrNull?.message, contains('192.168.1.100:9100'));

      await printer.close();
      fake.dispose();
    });
  });
}
