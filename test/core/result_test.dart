import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/src/core/result.dart';

void main() {
  group('Result', () {
    test('Ok handles when, valueOrNull, isOk', () {
      const Result<int> res = Result.ok(42);
      expect(res.isOk, isTrue);
      expect(res.isError, isFalse);
      expect(res.valueOrNull, 42);
      expect(res.errorOrNull, isNull);

      final result = res.when(
        ok: (v) => 'Success: $v',
        error: (e) => 'Failed: ${e.message}',
      );
      expect(result, 'Success: 42');
    });

    test('Err handles when, errorOrNull, isError', () {
      const error = PrinterError.paperOut;
      const Result<int> res = Result.error(error);
      expect(res.isOk, isFalse);
      expect(res.isError, isTrue);
      expect(res.valueOrNull, isNull);
      expect(res.errorOrNull, error);

      final result = res.when(
        ok: (v) => 'Success: $v',
        error: (e) => 'Failed: ${e.message}',
      );
      expect(result, 'Failed: The printer is out of paper.');
    });

    test('All predefined PrinterErrors have non-empty message and hint', () {
      final errors = <PrinterError>[
        PrinterError.permissionDenied,
        PrinterError.connectionLost,
        PrinterError.paperOut,
        PrinterError.coverOpen,
        PrinterError.connectionFailed(host: '192.168.1.1', port: 9100),
        PrinterError.timeout(host: '192.168.1.1'),
        PrinterError.unsupportedPlatform(transport: 'USB', platform: 'iOS'),
        PrinterError.fontMissing(language: 'Bangla'),
        PrinterError.renderFailed(reason: 'invalid bounds'),
        PrinterError.unknown(),
        PrinterError.unknown(detail: 'device busy'),
      ];

      for (final err in errors) {
        expect(err.message, isNotEmpty, reason: 'Message empty for ${err.code}');
        expect(err.hint, isNotEmpty, reason: 'Hint empty for ${err.code}');
      }
    });

    test('Result and PrinterError value equality', () {
      const ok1 = Result.ok('hello');
      const ok2 = Result.ok('hello');
      expect(ok1, equals(ok2));

      const err1 = Result<String>.error(PrinterError.paperOut);
      const err2 = Result<String>.error(PrinterError.paperOut);
      expect(err1, equals(err2));
    });
  });
}

