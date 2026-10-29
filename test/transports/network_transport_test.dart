import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/advanced.dart';

void main() {
  group('NetworkTransport Integration Tests (Skill 2)', () {
    test('connects to ServerSocket and transmits bytes', () async {
      // Bind local server on ephemeral port
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final serverReceived = Completer<List<int>>();

      server.listen((client) {
        final received = <int>[];
        client.listen((data) {
          received.addAll(data);
          if (received.length >= 2 && !serverReceived.isCompleted) {
            serverReceived.complete(received);
          }
        });
      });

      final transport = NetworkTransport('127.0.0.1', port: port);
      final connectRes = await transport.connect();
      expect(connectRes.isOk, isTrue);

      final writeRes = await transport.write(Uint8List.fromList([0x1B, 0x40]));
      expect(writeRes.isOk, isTrue);

      final received = await serverReceived.future.timeout(const Duration(seconds: 3));
      expect(received, [0x1B, 0x40]);

      await transport.disconnect();
      await server.close();
    });

    test('maps connection refusal to PrinterError.connectionFailed with host and port', () async {
      // Connect to an unused port on localhost
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final unusedPort = server.port;
      await server.close(); // Close immediately so it refuses connection

      final transport = NetworkTransport(
        '127.0.0.1',
        port: unusedPort,
        timeout: const Duration(seconds: 1),
      );
      final result = await transport.connect();

      expect(result.isError, isTrue);
      expect(result.errorOrNull?.code, PrinterErrorCode.connectionFailed);
      expect(result.errorOrNull?.message, contains('127.0.0.1:$unusedPort'));
      expect(result.errorOrNull?.hint, contains('port 9100'));
    });

    test('reconnects automatically if disconnected prior to write', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      var clientCount = 0;

      server.listen((client) {
        clientCount++;
        client.listen((data) {});
      });

      final transport = NetworkTransport('127.0.0.1', port: port);
      expect((await transport.connect()).isOk, isTrue);
      expect(clientCount, 1);

      // Force disconnect transport
      await transport.disconnect();

      // Write should re-trigger connect
      final writeRes = await transport.write(Uint8List.fromList([0x0A]));
      expect(writeRes.isOk, isTrue);
      expect(clientCount, 2);

      await transport.disconnect();
      await server.close();
    });
  });
}

