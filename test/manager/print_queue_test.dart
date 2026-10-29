// OLD: import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/advanced.dart';
// OLD: import 'package:posprint_kit/posprint_kit.dart';
// OLD: import 'package:posprint_kit/src/manager/print_queue.dart';

void main() {
  group('PrintQueue & PrinterManager (Skill 7)', () {
    test('jobs execute strictly one at a time in FIFO order', () async {
      final queue = PrintQueue();
      final executionOrder = <int>[];

      final job1 = queue.enqueue(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        executionOrder.add(1);
        return const Result.ok(1);
      });

      final job2 = queue.enqueue(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        executionOrder.add(2);
        return const Result.ok(2);
      });

      final results = await Future.wait([job1, job2]);

      expect(results[0].valueOrNull, 1);
      expect(results[1].valueOrNull, 2);
      expect(executionOrder, [1, 2]); // 1 must finish before 2 starts
    });

    test('retries on failure with specified backoff delays', () async {
      final queue = PrintQueue();
      var attempts = 0;

      final res = await queue.enqueue(
        () async {
          attempts++;
          if (attempts < 3) {
            // OLD: return const Result.error(PrinterError.connectionLost);
            return const Result<String>.error(PrinterError.connectionLost);
          }
          return const Result.ok('recovered');
        },
        maxRetries: 3,
        retryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 20),
        ],
      );

      expect(res.isOk, isTrue);
      expect(res.valueOrNull, 'recovered');
      expect(attempts, 3);
    });

    test('surfaces error when retries are exhausted', () async {
      final queue = PrintQueue();
      var attempts = 0;

      final res = await queue.enqueue(
        () async {
          attempts++;
          // OLD: return const Result.error(PrinterError.paperOut);
          return const Result<String>.error(PrinterError.paperOut);
        },
        maxRetries: 2,
        retryDelays: const [
          Duration(milliseconds: 10),
          Duration(milliseconds: 10),
        ],
      );

      expect(res.isError, isTrue);
      expect(res.errorOrNull?.code, PrinterErrorCode.paperOut);
      expect(attempts, 3); // initial + 2 retries
    });

    test('two concurrent print calls do not interleave bytes (Skill 7)', () async {
      // 8 PM rush scenario: order A and order B submitted 20 ms apart
      final fake = FakeTransport(
        writeDelay: const Duration(milliseconds: 30),
      );
      final printer = EscposPrinter.custom(fake);

      final orderA = Receipt()..title('ORDER A')..cut();
      final orderB = Receipt()..title('ORDER B')..cut();

      final aFuture = printer.print(orderA);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final bFuture = printer.print(orderB);

      final results = await Future.wait([aFuture, bFuture]);
      expect(results[0].isOk, isTrue);
      expect(results[1].isOk, isTrue);

      final allBytes = fake.recordedBytes;
      final str = String.fromCharCodes(allBytes);

      final indexA = str.indexOf('ORDER A');
      final indexB = str.indexOf('ORDER B');

      expect(indexA, isNonNegative);
      expect(indexB, isNonNegative);
      expect(indexA, lessThan(indexB));

      await printer.close();
    });
  });
}
