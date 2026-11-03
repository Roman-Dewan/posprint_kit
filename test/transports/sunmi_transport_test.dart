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

  group('SunmiTransport Unit Tests', () {
    test('isSunmiDevice returns true when supported by platform', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.isSupported') {
          return true;
        }
        return null;
      });

      final isSunmi = await SunmiTransport.isSunmiDevice();
      expect(isSunmi, isTrue);
    });

    test('isSunmiDevice returns false when not a Sunmi device', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.isSupported') {
          return false;
        }
        return null;
      });

      final isSunmi = await SunmiTransport.isSunmiDevice();
      expect(isSunmi, isFalse);
    });

    test('getPaperWidth queries platform channel and parses 80 mm and 58 mm',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.getPaperWidth') {
          return 80;
        }
        return null;
      });

      final width80 = await SunmiTransport.getPaperWidth();
      expect(width80, 80);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.getPaperWidth') {
          return 58;
        }
        return null;
      });

      final width58 = await SunmiTransport.getPaperWidth();
      expect(width58, 58);
    });

    test('getStatus returns status string from platform', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.getStatus') {
          return 'NORMAL';
        }
        return null;
      });

      final res = await SunmiTransport.getStatus();
      expect(res.isOk, isTrue);
      expect(res.valueOrNull, 'NORMAL');
    });

    test('openDrawer invokes sunmi.openDrawer method call', () async {
      var drawerCalled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.openDrawer') {
          drawerCalled = true;
          return true;
        }
        return null;
      });

      final res = await SunmiTransport.openDrawer();
      expect(res.isOk, isTrue);
      expect(drawerCalled, isTrue);

      final transport = SunmiTransport();
      final res2 = await transport.kickDrawer();
      expect(res2.isOk, isTrue);
    });

    test('openDrawer maps DRAWER_FAILED to PrinterError with actionable hint',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.openDrawer') {
          throw PlatformException(
            code: 'DRAWER_FAILED',
            message: 'Failed to pulse drawer.',
          );
        }
        return null;
      });

      final res = await SunmiTransport.openDrawer();
      expect(res.isError, isTrue);
      expect(res.errorOrNull?.message, contains('Failed to pulse drawer'));
      expect(res.errorOrNull?.hint, contains('RJ12'));
    });

    test('connect, write, and disconnect execute successfully with state flow',
        () async {
      final methodCalls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'sunmi.connect':
            return true;
          case 'sunmi.write':
            return true;
          case 'sunmi.disconnect':
            return null;
          default:
            return null;
        }
      });

      final transport = SunmiTransport();
      final states = <PosConnectionState>[];
      final sub = transport.state.listen(states.add);

      expect(transport.currentState, PosConnectionState.disconnected);

      final connectRes = await transport.connect();
      expect(connectRes.isOk, isTrue);
      expect(transport.currentState, PosConnectionState.connected);

      final writeRes =
          await transport.write(Uint8List.fromList([0x1B, 0x40, 0x0A]));
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
        'sunmi.connect',
        'sunmi.write',
        'sunmi.disconnect',
      ]);
    });

    test('connect maps NOT_SUNMI_DEVICE to unsupportedPlatform', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.connect') {
          throw PlatformException(
            code: 'NOT_SUNMI_DEVICE',
            message: 'Device is not manufactured by Sunmi.',
          );
        }
        return null;
      });

      final transport = SunmiTransport();
      final res = await transport.connect();

      expect(res.isError, isTrue);
      final err = res.errorOrNull!;
      expect(err.code, PrinterErrorCode.unsupportedPlatform);
      expect(err.hint, contains('Sunmi POS terminals'));
      expect(transport.currentState, PosConnectionState.disconnected);
    });

    test('connect maps NO_PRINTER to deviceNotFound', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.connect') {
          throw PlatformException(
            code: 'NO_PRINTER',
            message: 'No default built-in printer found.',
          );
        }
        return null;
      });

      final transport = SunmiTransport();
      final res = await transport.connect();

      expect(res.isError, isTrue);
      final err = res.errorOrNull!;
      expect(err.code, PrinterErrorCode.connectionFailed);
      expect(err.hint, contains('integrated thermal receipt printer'));
      expect(transport.currentState, PosConnectionState.disconnected);
    });

    test('write maps WRITE_FAILED to connectionLost', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'sunmi.connect') return true;
        if (call.method == 'sunmi.write') {
          throw PlatformException(
            code: 'WRITE_FAILED',
            message: 'IPC channel closed.',
          );
        }
        return null;
      });

      final transport = SunmiTransport();
      await transport.connect();

      final res = await transport.write(Uint8List.fromList([0x0A]));
      expect(res.isError, isTrue);
      expect(res.errorOrNull?.code, PrinterErrorCode.connectionLost);
      expect(transport.currentState, PosConnectionState.disconnected);
    });

    test('EscposPrinter.sunmi and EscposPrinter.inbuilt facades instantiate properly',
        () {
      final sunmiPrinter = EscposPrinter.sunmi();
      expect(sunmiPrinter.transport, isA<SunmiTransport>());
      expect(sunmiPrinter.profile, PrinterProfile.sunmi80);
      expect(sunmiPrinter.profile.rasterizeAllText, isTrue);

      final inbuiltPrinter = EscposPrinter.inbuilt(profile: PrinterProfile.sunmi58);
      expect(inbuiltPrinter.transport, isA<SunmiTransport>());
      expect(inbuiltPrinter.profile, PrinterProfile.sunmi58);
      expect(inbuiltPrinter.profile.rasterizeAllText, isTrue);
    });

    test('SunmiTransport.printReceipt serializes operations and executes via native LineApi channel',
        () async {
      final invokedCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        invokedCalls.add(call);
        if (call.method == 'sunmi.connect') return true;
        if (call.method == 'sunmi.printReceipt') return true;
        return null;
      });

      final transport = SunmiTransport();
      final receipt = Receipt()
        ..title('5-COLUMN BISTRO ORDER')
        ..text('Order #1042', align: PosAlign.center)
        ..divider()
        ..row('Item 1', '10.00')
        ..columns([
          const PosColumn(text: '#', width: 1),
          const PosColumn(text: 'Item', width: 5),
        ])
        ..qr('https://sunmi.com', size: 4)
        ..barcode('10429812')
        ..feed(2)
        ..cut()
        ..drawer();

      final res = await transport.printReceipt(receipt, profile: PrinterProfile.sunmi80);
      expect(res.isOk, isTrue);

      final printCall = invokedCalls.firstWhere((c) => c.method == 'sunmi.printReceipt');
      expect(printCall, isNotNull);

      final args = printCall.arguments as Map<dynamic, dynamic>;
      expect(args['is58mm'], isFalse);

      final ops = (args['ops'] as List<dynamic>).cast<Map<dynamic, dynamic>>();
      expect(ops.length, 10);
      expect(ops[0]['type'], 'text');
      expect(ops[0]['text'], '5-COLUMN BISTRO ORDER');
      expect(ops[0]['fontSize'], 36); // prominent double-size title
      expect(ops[2]['type'], 'divider');
      expect(ops[2]['character'], '-');
      expect(ops[3]['type'], 'row');
      expect(ops[4]['type'], 'columns');
      expect(ops[5]['type'], 'qr');
      expect(ops[6]['type'], 'barcode');
      expect(ops[7]['type'], 'feed');
      expect(ops[8]['type'], 'cut');
      expect(ops[9]['type'], 'drawer');
    });
  });
}
