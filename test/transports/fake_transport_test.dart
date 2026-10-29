import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/advanced.dart';

void main() {
  group('FakeTransport Tests', () {
    test('connect, write, and disconnect transition states', () async {
      final fake = FakeTransport();
      final states = <PosConnectionState>[];
      final sub = fake.state.listen(states.add);

      expect(fake.currentState, PosConnectionState.disconnected);

      final connectRes = await fake.connect();
      expect(connectRes.isOk, isTrue);
      expect(fake.currentState, PosConnectionState.connected);

      final writeRes = await fake.write(Uint8List.fromList([1, 2, 3]));
      expect(writeRes.isOk, isTrue);
      expect(fake.recordedBytes, [1, 2, 3]);

      await fake.disconnect();
      // Allow stream broadcast events to flush
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fake.currentState, PosConnectionState.disconnected);

      expect(states, [
        PosConnectionState.connecting,
        PosConnectionState.connected,
        PosConnectionState.disconnecting,
        PosConnectionState.disconnected,
      ]);

      await sub.cancel();
      fake.dispose();
    });

    test('injecting nextConnectError produces expected error', () async {
      final fake = FakeTransport()..nextConnectError = PrinterError.permissionDenied;
      final res = await fake.connect();
      expect(res.isError, isTrue);
      expect(res.errorOrNull?.code, PrinterErrorCode.permissionDenied);
    });

    test('injecting nextWriteError produces expected error', () async {
      final fake = FakeTransport()..nextWriteError = PrinterError.connectionLost;
      await fake.connect();
      final res = await fake.write(Uint8List.fromList([0x1B, 0x40]));
      expect(res.isError, isTrue);
      expect(res.errorOrNull?.code, PrinterErrorCode.connectionLost);
    });

    test('write fails if not connected', () async {
      final fake = FakeTransport();
      final res = await fake.write(Uint8List.fromList([1]));
      expect(res.isError, isTrue);
      expect(res.errorOrNull?.code, PrinterErrorCode.connectionLost);
    });
  });
}
