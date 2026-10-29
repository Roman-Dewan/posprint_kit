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

  group('BluetoothTransport Unit Tests', () {
    test('listPairedDevices parses paired device list correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'bt.listPaired') {
          return [
            {'name': 'Thermal Printer 80', 'address': '00:11:22:33:44:55'},
            {'name': 'POS-58', 'address': 'AA:BB:CC:DD:EE:FF'},
          ];
        }
        return null;
      });

      final result = await BluetoothTransport.listPairedDevices();
      expect(result.isOk, isTrue);
      final devices = result.valueOrNull!;
      expect(devices.length, 2);
      expect(devices[0].name, 'Thermal Printer 80');
      expect(devices[0].address, '00:11:22:33:44:55');
      expect(devices[1].name, 'POS-58');
      expect(devices[1].address, 'AA:BB:CC:DD:EE:FF');
    });

    test('listPairedDevices handles empty list', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'bt.listPaired') {
          return <Map<String, dynamic>>[];
        }
        return null;
      });

      final result = await BluetoothTransport.listPairedDevices();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!, isEmpty);
    });

    test('listPairedDevices maps PERMISSION_DENIED to actionable PrinterError', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'bt.listPaired') {
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'BLUETOOTH_CONNECT permission not granted.',
          );
        }
        return null;
      });

      final result = await BluetoothTransport.listPairedDevices();
      expect(result.isError, isTrue);
      final err = result.errorOrNull!;
      expect(err.code, PrinterErrorCode.permissionDenied);
      expect(err.hint, contains('BLUETOOTH_CONNECT'));
    });

    test('listPairedDevices maps BLUETOOTH_DISABLED to actionable PrinterError', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'bt.listPaired') {
          throw PlatformException(
            code: 'BLUETOOTH_DISABLED',
            message: 'Bluetooth adapter is turned off.',
          );
        }
        return null;
      });

      final result = await BluetoothTransport.listPairedDevices();
      expect(result.isError, isTrue);
      final err = result.errorOrNull!;
      expect(err.code, PrinterErrorCode.connectionFailed);
      expect(err.hint, contains('Enable Bluetooth'));
    });

    test('requestPermission returns true when granted', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'bt.requestPermission') {
          return true;
        }
        return null;
      });

      final result = await BluetoothTransport.requestPermission();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('requestPermission maps PERMISSION_DENIED error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'bt.requestPermission') {
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'Bluetooth permissions were denied.',
          );
        }
        return null;
      });

      final result = await BluetoothTransport.requestPermission();
      expect(result.isError, isTrue);
      expect(result.errorOrNull?.code, PrinterErrorCode.permissionDenied);
    });

    test('connect, write, and disconnect work with valid responses', () async {
      final methodCalls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'bt.connect':
            return true;
          case 'bt.write':
            return true;
          case 'bt.disconnect':
            return true;
          default:
            return null;
        }
      });

      final transport = BluetoothTransport('00:11:22:33:44:55');
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
        'bt.connect',
        'bt.write',
        'bt.disconnect',
      ]);
      expect(methodCalls[0].arguments, {'address': '00:11:22:33:44:55'});
    });

    test('connect maps CONNECTION_FAILED to friendly PrinterError', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'bt.connect') {
          throw PlatformException(
            code: 'CONNECTION_FAILED',
            message: 'Unable to connect to RFCOMM socket.',
          );
        }
        return null;
      });

      final transport = BluetoothTransport('00:11:22:33:44:55');
      final res = await transport.connect();

      expect(res.isError, isTrue);
      final err = res.errorOrNull!;
      expect(err.code, PrinterErrorCode.connectionFailed);
      expect(err.hint, contains('turned on'));
      expect(transport.currentState, PosConnectionState.disconnected);
    });

    test('write maps WRITE_FAILED to connectionLost', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'bt.connect') return true;
        if (call.method == 'bt.write') {
          throw PlatformException(
            code: 'WRITE_FAILED',
            message: 'Broken pipe / disconnected.',
          );
        }
        return null;
      });

      final transport = BluetoothTransport('00:11:22:33:44:55');
      await transport.connect();

      final res = await transport.write(Uint8List.fromList([0x0A]));
      expect(res.isError, isTrue);
      expect(res.errorOrNull?.code, PrinterErrorCode.connectionLost);
      expect(transport.currentState, PosConnectionState.disconnected);
    });
  });
}
