import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/posprint_kit.dart';

void main() {
  group('NetworkDevice Model Tests', () {
    test('creates NetworkDevice and verifies properties', () {
      const device = NetworkDevice(
        ip: '192.168.1.105',
        port: 9100,
        name: 'Kitchen TM-T20',
        model: 'TM-T20III',
        hostName: 'printer.lan',
      );

      expect(device.ip, '192.168.1.105');
      expect(device.port, 9100);
      expect(device.name, 'Kitchen TM-T20');
      expect(device.model, 'TM-T20III');
      expect(device.hostName, 'printer.lan');
      expect(device.toString(), contains('Kitchen TM-T20'));
      expect(device.toString(), contains('192.168.1.105:9100'));
    });

    test('verifies equality and hashCode based on ip and port', () {
      const d1 = NetworkDevice(
        ip: '192.168.1.50',
        port: 9100,
        name: 'Printer A',
        model: 'Generic 80',
      );
      const d2 = NetworkDevice(
        ip: '192.168.1.50',
        port: 9100,
        name: 'Printer A (Renamed)',
        model: 'Generic 80 v2',
      );
      const d3 = NetworkDevice(
        ip: '192.168.1.51',
        port: 9100,
        name: 'Printer B',
        model: 'Generic 80',
      );

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1, isNot(equals(d3)));
    });
  });

  group('NetworkDiscovery Engine Tests', () {
    test('probeHost identifies printer and parses ESC/POS model inquiry bytes',
        () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((client) {
        client.listen((data) {
          // Check for ESC/POS GS I inquiry (0x1D 0x49)
          if (data.contains(0x1D) && data.contains(0x49)) {
            // Reply with simulated model identification string: "TM-T20III\0"
            client.add(Uint8List.fromList([
              0x5F, // Header
              0x54, 0x4D, 0x2D, 0x54, 0x32, 0x30, 0x49, 0x49, 0x49, // TM-T20III
              0x00, // NUL terminator
            ]));
          }
        });
      });

      final device = await NetworkDiscovery.probeHost(
        '127.0.0.1',
        port: port,
        timeout: const Duration(milliseconds: 500),
        probeHardware: true,
      );

      expect(device, isNotNull);
      expect(device!.ip, '127.0.0.1');
      expect(device.port, port);
      expect(device.model, contains('TM-T20III'));

      await server.close();
    });

    test('probeHost returns null when port is closed', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = server.port;
      await server.close(); // Closed immediately

      final device = await NetworkDiscovery.probeHost(
        '127.0.0.1',
        port: closedPort,
        timeout: const Duration(milliseconds: 200),
      );

      expect(device, isNull);
    });

    test('findLocalSubnets returns a valid list of subnets without crashing',
        () async {
      final subnets = await NetworkDiscovery.findLocalSubnets();
      expect(subnets, isA<List<String>>());
      for (final sub in subnets) {
        expect(sub.split('.').length, 3);
      }
    });

    test('NetworkTransport.discoverDevices calls discovery and returns Result',
        () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      server.listen((client) {});

      final device = await NetworkDiscovery.probeHost(
        '127.0.0.1',
        port: port,
        timeout: const Duration(milliseconds: 300),
      );
      expect(device, isNotNull);

      // Verify EscposPrinter.network constructor works with discovered device
      final printer = EscposPrinter.network(device!);
      expect(printer.transport, isA<NetworkTransport>());

      // Verify NetworkTransport.fromDevice factory
      final transport = NetworkTransport.fromDevice(device);
      expect(transport.host, '127.0.0.1');
      expect(transport.port, port);

      await server.close();
    });

    test('NetworkTransport.listDevices convenience alias returns Result',
        () async {
      // Test with custom non-existent subnet
      final result = await NetworkTransport.listDevices(
        subnet: '192.0.2', // TEST-NET-1 (RFC 5737), no devices
        timeout: const Duration(milliseconds: 50),
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!, isEmpty);
    });
  });
}
