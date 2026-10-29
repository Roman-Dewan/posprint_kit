import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/advanced.dart';
// OLD: import 'package:posprint_kit/posprint_kit.dart';

void main() {
  group('EscposPrinter Facade (The 3-line test)', () {
    test('prints in 3 lines using FakeTransport', () async {
      final fake = FakeTransport();
      final printer = EscposPrinter.custom(fake);

      // Line 1: Build receipt
      final receipt = Receipt()..title('FAST BURGER')..row('Burger x1', '6.00')..cut();

      // Line 2: Print
      final result = await printer.print(receipt);

      // Line 3: Close
      await printer.close();

      expect(result.isOk, isTrue);
      expect(fake.recordedBytes, isNotEmpty);
      expect(fake.recordedBytes.sublist(0, 2), Commands.init);
    });

    test('chunks large writes according to maxChunkSize', () async {
      final fake = FakeTransport(maxChunkSize: 64);
      final printer = EscposPrinter.custom(fake);

      // Add enough text lines to produce > 64 bytes
      final receipt = Receipt();
      for (var i = 0; i < 10; i++) {
        receipt.text('Long line item number $i in receipt');
      }

      final result = await printer.print(receipt);
      expect(result.isOk, isTrue);
      expect(fake.writtenChunks.length, greaterThan(1));
      for (final chunk in fake.writtenChunks) {
        expect(chunk.length, lessThanOrEqualTo(64));
      }
    });

    test('surfaces friendly error if connection fails', () async {
      // OLD: final fake = FakeTransport()..nextConnectError = PrinterError.connectionLost;
      final fake = FakeTransport()..persistentConnectError = PrinterError.connectionLost;
      final printer = EscposPrinter.custom(fake);

      final result = await printer.print(Receipt()..text('Hi'));
      expect(result.isError, isTrue);
      expect(result.errorOrNull?.code, PrinterErrorCode.connectionLost);
      expect(result.errorOrNull?.hint, isNotEmpty);
    });

    test('printTestPage outputs ruler and languages', () async {
      final fake = FakeTransport();
      final printer = EscposPrinter.custom(fake);

      final result = await printer.printTestPage();
      expect(result.isOk, isTrue);
      expect(fake.recordedBytes, containsAllInOrder(Commands.cutFull));
    });

    test('EscposLink.isSupported checks platforms', () {
      expect(EscposLink.isSupported(Transport.wifi), isTrue);
    });

    test('EscposLink.logLevel controls logger', () {
      EscposLink.logLevel = LogLevel.verbose;
      expect(EscposLink.logLevel, LogLevel.verbose);
      EscposLink.logLevel = LogLevel.warning;
    });

    test('plain-language debug asserts fire with clear messages', () {
      expect(
        () => EscposPrinter.wifi(''),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('Printer IP/host address cannot be empty'),
          ),
        ),
      );

      expect(
        () => EscposPrinter.wifi('192.168.1.1', port: 0),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('port must be between 1 and 65535'),
          ),
        ),
      );
    });
  });
}
