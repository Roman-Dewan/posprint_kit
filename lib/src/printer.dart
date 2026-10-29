import 'dart:io' show Platform;
// OLD: import 'dart:typed_data';
import 'core/logger.dart';
import 'core/ops.dart';
import 'core/printer_profile.dart';
import 'core/receipt.dart';
// OLD: import 'core/receipt_encoder.dart';
import 'core/result.dart';
import 'core/text_rasterizer.dart';
import 'doctor/doctor.dart';
import 'manager/printer_manager.dart';
import 'transports/bluetooth_transport.dart';
import 'transports/fake_transport.dart';
import 'transports/network_transport.dart';
import 'transports/printer_transport.dart';
import 'transports/usb_transport.dart';

/// Available physical transport channels.
enum Transport {
  /// Local network or WiFi TCP connection (default port 9100).
  wifi,

  /// Classic Bluetooth Serial Port Profile (SPP, Android).
  bluetooth,

  /// Bluetooth Low Energy (Android and iOS).
  ble,

  /// USB OTG cable connection (Android).
  usb,
}

/// Beginner-friendly primary facade for connecting to and printing with ESC/POS printers.
///
/// Designed so that any developer can print a complete receipt in about 3 lines:
/// ```dart
/// final printer = EscposPrinter.wifi('192.168.1.50');
/// await printer.print(Receipt()..text('Hello!')..cut());
/// await printer.close();
/// ```
class EscposPrinter {
  /// Connects to a network or WiFi thermal printer at [host] on [port] (default 9100).
  ///
  /// ```dart
  /// final printer = EscposPrinter.wifi('192.168.1.50');
  /// ```
  EscposPrinter.wifi(
    String host, {
    int port = 9100,
    this.profile = PrinterProfile.generic80,
    TextRasterizer? rasterizer,
  })  : assert(
          host.trim().isNotEmpty,
          'Printer IP/host address cannot be empty. Example: "192.168.1.50"',
        ),
        assert(
          port > 0 && port <= 65535,
          'Printer port must be between 1 and 65535 (standard receipt printers use 9100).',
        ),
        transport = NetworkTransport(host, port: port),
        rasterizer = rasterizer ?? const FakeRasterizer();

  /// Connects to a paired Bluetooth Classic printer on Android using its MAC [address].
  ///
  /// ```dart
  /// final printer = EscposPrinter.bluetooth('00:11:22:33:44:55');
  /// ```
  EscposPrinter.bluetooth(
    String address, {
    this.profile = PrinterProfile.generic58,
    TextRasterizer? rasterizer,
  })  : assert(
          address.trim().isNotEmpty,
          'Bluetooth device address/MAC cannot be empty.',
        ),
        // OLD: transport = FakeTransport(maxChunkSize: 512),
        transport = BluetoothTransport(address, maxChunkSize: 512),
        rasterizer = rasterizer ?? const FakeRasterizer();

  /// Connects to a thermal printer plugged in via USB OTG on Android.
  EscposPrinter.usb({
    required int vendorId,
    required int productId,
    this.profile = PrinterProfile.generic80,
    TextRasterizer? rasterizer,
  })  : assert(vendorId > 0, 'vendorId must be a positive integer.'),
        assert(productId > 0, 'productId must be a positive integer.'),
        // OLD: transport = FakeTransport(maxChunkSize: 4096),
        transport = UsbTransport(vendorId: vendorId, productId: productId, maxChunkSize: 4096),
        rasterizer = rasterizer ?? const FakeRasterizer();

  /// Custom constructor allowing injection of any [PrinterTransport] (e.g. [FakeTransport]).
  EscposPrinter.custom(
    this.transport, {
    this.profile = PrinterProfile.generic80,
    TextRasterizer? rasterizer,
  }) : rasterizer = rasterizer ?? const FakeRasterizer();

  /// The active communication transport.
  final PrinterTransport transport;

  /// Physical capabilities and column specifications of the target printer.
  final PrinterProfile profile;

  /// Seam for text rasterization.
  final TextRasterizer rasterizer;

  /// Underlying manager coordinating queueing, retries, and chunking.
  late final PrinterManager manager = PrinterManager(
    transport: transport,
    profile: profile,
    rasterizer: rasterizer,
  );

  /// Connection state stream.
  Stream<PosConnectionState> get state => manager.state;

  /// The current connection state.
  PosConnectionState get currentState => manager.currentState;

  /// Encodes and sends [receipt] to the printer through the FIFO queue.
  // OLD:
  // Future<Result<void>> print(Receipt receipt) async {
  //   if (transport.currentState != PosConnectionState.connected) {
  //     PosLogger.info('Opening connection before printing...');
  //     final connectRes = await transport.connect();
  //     if (connectRes.isError) {
  //       return connectRes;
  //     }
  //   }
  //   final encoder = ReceiptEncoder(profile, rasterizer);
  //   final encodeRes = await encoder.encode(receipt);
  //   if (encodeRes.isError) {
  //     return Result.error(encodeRes.errorOrNull!);
  //   }
  //   final bytes = encodeRes.valueOrNull!;
  //   PosLogger.verbose('Writing ${bytes.length} bytes to printer...');
  //   final maxChunk = transport.maxChunkSize;
  //   if (bytes.length <= maxChunk) {
  //     return transport.write(bytes);
  //   }
  //   var offset = 0;
  //   while (offset < bytes.length) {
  //     final chunkSize = (bytes.length - offset).clamp(0, maxChunk);
  //     final chunk = Uint8List.sublistView(bytes, offset, offset + chunkSize);
  //     final writeRes = await transport.write(chunk);
  //     if (writeRes.isError) {
  //       return writeRes;
  //     }
  //     offset += chunkSize;
  //   }
  //   return const Result.ok(null);
  // }
  Future<Result<void>> print(Receipt receipt) => manager.print(receipt);

  /// Prints a comprehensive test receipt containing a measurement ruler, QR code,
  /// and sample phrases in all major supported languages (Bangla, Chinese, Japanese,
  /// Arabic, Hindi, etc.).
  ///
  /// Useful for junior developers to confirm setup and font support before designing receipts.
  Future<Result<void>> printTestPage() {
    final ruler = '-' * profile.columnsNormal;
    final receipt = Receipt()
      ..title('PRINTER TEST PAGE')
      ..text('posprint_kit diagnostic receipt', align: PosAlign.center)
      ..divider()
      ..text(ruler)
      ..text('Width: ${profile.dotsWidth} dots | Cols: ${profile.columnsNormal}')
      ..divider()
      ..text('English: Thank you for your visit!')
      ..text('Español: Café crème brûlée & Niño')
      ..text('Bangla: ধন্যবাদ (ক্ষুদ্র ও মিষ্টি দই)')
      ..text('Hindi: हमारे भोजनालय में आपका स्वागत है')
      ..text('Chinese: 谢谢惠顾，欢迎再次光临', languageTag: 'zh-Hans')
      ..text('Japanese: 毎度ありがとうございます', languageTag: 'ja')
      ..text('Korean: 저희 매장을 이용해 주셔서 감사합니다')
      ..text('Arabic: شكراً لزيارتكم الكريمة', languageTag: 'ar')
      ..text('Thai: ขอบคุณที่ใช้บริการครับ', languageTag: 'th')
      ..divider()
      ..qr('https://pub.dev')
      ..feed(2)
      ..cut();

    return print(receipt);
  }

  /// Closes the transport connection and releases resources.
  Future<void> close() async {
    PosLogger.info('Closing printer connection...');
    // OLD: await transport.disconnect();
    await manager.close();
  }
}

/// Global settings and environment checks for the library.
class EscposLink {
  EscposLink._();

  /// Gets or sets the package-wide logging threshold.
  static LogLevel get logLevel => PosLogger.level;
  static set logLevel(LogLevel level) => PosLogger.level = level;

  /// Runs diagnostic checks on operating system, permissions, and transport capabilities.
  ///
  /// ```dart
  /// final report = await EscposLink.doctor();
  /// print(report);
  /// ```
  static Future<DoctorReport> doctor() => Doctor.check();

  /// Checks whether [transport] is supported on the current running operating system.
  static bool isSupported(Transport transport) {
    try {
      if (Platform.isAndroid) {
        return true; // Android supports WiFi, BT Classic, BLE, USB
      }
      if (Platform.isIOS) {
        // iOS supports WiFi and BLE (does not allow generic USB or BT Classic SPP)
        return transport == Transport.wifi || transport == Transport.ble;
      }
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Desktops support WiFi directly via TCP sockets
        return transport == Transport.wifi;
      }
    } catch (_) {
      // Running in environment without dart:io platform
    }
    return transport == Transport.wifi;
  }
}

/// Convenient alias matching package naming.
typedef PosPrintKit = EscposLink;
