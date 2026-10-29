import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('posprint_kit');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('UsbTransport Unit Tests', () {
    test('listDevices parses attached USB devices correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'usb.list') {
          return [
            {
              'vendorId': 0x04b8,
              'productId': 0x0202,
              'name': 'Epson TM-T88V',
              'deviceName': '/dev/bus/usb/001/002',
              'hasPermission': true,
            },
            {
              'vendorId': 0x0416,
              'productId': 0x5011,
              'name': 'POS58 USB Printer',
              'deviceName': '/dev/bus/usb/001/003',
              'hasPermission': false,
            },
          ];
        }
        return null;
      });

      final result = await UsbTransport.listDevices();
      expect(result.isOk, isTrue);
      final devices = result.valueOrNull!;
      expect(devices.length, 2);
      expect(devices[0].vendorId, 0x04b8);
      expect(devices[0].productId, 0x0202);
      expect(devices[0].name, 'Epson TM-T88V');
      expect(devices[0].hasPermission, isTrue);

      expect(devices[1].vendorId, 0x0416);
      expect(devices[1].productId, 0x5011);
      expect(devices[1].name, 'POS58 USB Printer');
      expect(devices[1].hasPermission, isFalse);
    });

    test('listDevices handles empty device list', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'usb.list') {
          return <Map<String, dynamic>>[];
        }
        return null;
      });

      final result = await UsbTransport.listDevices();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!, isEmpty);
    });

    test('requestPermission sends vendorId and productId and returns result', () async {
      MethodCall? recordedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'usb.requestPermission') {
          recordedCall = call;
          return true;
        }
        return null;
      });

      final result = await UsbTransport.requestPermission(0x04b8, 0x0202);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isTrue);
      expect(recordedCall?.arguments, {'vendorId': 0x04b8, 'productId': 0x0202});
    });

    test('connect, write, and disconnect work with valid responses', () async {
      final methodCalls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'usb.connect':
            return true;
          case 'usb.write':
            return true;
          case 'usb.disconnect':
            return true;
          default:
            return null;
        }
      });

      final transport = UsbTransport(vendorId: 0x04b8, productId: 0x0202);
      final states = <PosConnectionState>[];
      final sub = transport.state.listen(states.add);

      expect(transport.currentState, PosConnectionState.disconnected);

      final connectRes = await transport.connect();
      expect(connectRes.isOk, isTrue);
      expect(transport.currentState, PosConnectionState.connected);

      final writeRes = await transport.write(Uint8List.fromList([0x1B, 0x40]));
      expect(writeRes.isOk, isTrue);

      await transport.disconnect();
      expect(transport.currentState, PosConnectionState.disconnected);

      await sub.cancel();

      expect(states, [
        PosConnectionState.connecting,
        PosConnectionState.connected,
        PosConnectionState.disconnecting,
        PosConnectionState.disconnected,
      ]);

      expect(methodCalls.map((c) => c.method), [
        'usb.connect',
        'usb.write',
        'usb.disconnect',
      ]);
      expect(methodCalls[0].arguments, {'vendorId': 0x04b8, 'productId': 0x0202});
    });

    test('connect maps PERMISSION_DENIED to actionable PrinterError', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'usb.connect') {
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'USB permission not granted.',
          );
        }
        return null;
      });

      final transport = UsbTransport(vendorId: 0x04b8, productId: 0x0202);
      final res = await transport.connect();

      expect(res.isError, isTrue);
      final err = res.errorOrNull!;
      expect(err.code, PrinterErrorCode.permissionDenied);
      expect(err.hint, contains('permission dialog'));
      expect(transport.currentState, PosConnectionState.disconnected);
    });

    test('connect maps DEVICE_NOT_FOUND to connectionFailed with hint', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'usb.connect') {
          throw PlatformException(
            code: 'DEVICE_NOT_FOUND',
            message: 'No USB device matched VID/PID.',
          );
        }
        return null;
      });

      final transport = UsbTransport(vendorId: 0x04b8, productId: 0x0202);
      final res = await transport.connect();

      expect(res.isError, isTrue);
      final err = res.errorOrNull!;
      expect(err.code, PrinterErrorCode.connectionFailed);
      expect(err.hint, contains('USB cable'));
    });

    test('connect maps NO_ENDPOINT to connectionFailed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'usb.connect') {
          throw PlatformException(
            code: 'NO_ENDPOINT',
            message: 'No bulk OUT endpoint found on USB device.',
          );
        }
        return null;
      });

      final transport = UsbTransport(vendorId: 0x04b8, productId: 0x0202);
      final res = await transport.connect();

      expect(res.isError, isTrue);
      final err = res.errorOrNull!;
      expect(err.code, PrinterErrorCode.connectionFailed);
      expect(err.message, contains('bulk-transfer'));
      expect(err.hint, contains('USB cable'));
    });

    test('write maps WRITE_FAILED to connectionLost', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'usb.connect') return true;
        if (call.method == 'usb.write') {
          throw PlatformException(
            code: 'WRITE_FAILED',
            message: 'USB bulk transfer failed.',
          );
        }
        return null;
      });

      final transport = UsbTransport(vendorId: 0x04b8, productId: 0x0202);
      await transport.connect();

      final res = await transport.write(Uint8List.fromList([0x0A]));
      expect(res.isError, isTrue);
      expect(res.errorOrNull?.code, PrinterErrorCode.connectionLost);
      expect(transport.currentState, PosConnectionState.disconnected);
    });
  });
}
