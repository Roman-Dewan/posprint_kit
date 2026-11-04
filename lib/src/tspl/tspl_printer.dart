import 'dart:convert';
import 'dart:typed_data';

import '../core/logger.dart';
import '../core/result.dart';
import '../core/text_rasterizer.dart';
import '../manager/print_queue.dart';
import '../transports/bluetooth_transport.dart';
import '../transports/network_transport.dart';
import '../transports/printer_transport.dart';
import '../transports/usb_transport.dart';
import 'tspl_encoder.dart';
import 'tspl_label.dart';

/// Beginner-friendly primary facade for connecting to and printing with
/// TSPL / TSPL2 thermal label and barcode sticker printers.
///
/// Supports exactly three physical transports: **USB**, **WiFi**, and **Bluetooth**.
///
/// Example:
/// ```dart
/// // 1. Connect via USB OTG
/// final printer = TsplPrinter.usb(vendorId: 0x0483, productId: 0x5740);
///
/// // Or via Bluetooth Classic (Android)
/// final printer = TsplPrinter.bluetooth('00:11:22:33:44:55');
///
/// // Or via WiFi / Ethernet TCP
/// final printer = TsplPrinter.wifi('192.168.1.100');
///
/// // 2. Build and print label
/// final label = TsplLabel(size: TsplSize.size40x30)
///   ..text('STORE LABEL', x: 20, y: 20)
///   ..barcode('12345678', x: 20, y: 60, height: 40)
///   ..print(copies: 1);
///
/// await printer.print(label);
/// await printer.close();
/// ```
class TsplPrinter {
  /// Connects to a network or WiFi label printer at [host] on [port] (default 9100).
  TsplPrinter.wifi(
    String host, {
    int port = 9100,
    TextRasterizer? rasterizer,
    PrintQueue? queue,
  })  : assert(
          host.trim().isNotEmpty,
          'Printer IP/host address cannot be empty. Example: "192.168.1.100"',
        ),
        assert(
          port > 0 && port <= 65535,
          'Printer port must be between 1 and 65535.',
        ),
        transport = NetworkTransport(host, port: port),
        encoder = TsplEncoder(rasterizer: rasterizer ?? const FakeRasterizer()),
        queue = queue ?? PrintQueue();

  /// Connects to a paired Bluetooth Classic label printer on Android using its MAC [address].
  TsplPrinter.bluetooth(
    String address, {
    TextRasterizer? rasterizer,
    int maxChunkSize = 256,
    Duration chunkDelay = const Duration(milliseconds: 25),
    PrintQueue? queue,
  })  : assert(
          address.trim().isNotEmpty,
          'Bluetooth device address/MAC cannot be empty.',
        ),
        transport = BluetoothTransport(
          address,
          maxChunkSize: maxChunkSize,
          chunkDelay: chunkDelay,
        ),
        encoder = TsplEncoder(rasterizer: rasterizer ?? const FakeRasterizer()),
        queue = queue ?? PrintQueue();

  /// Connects to a label printer plugged in via USB OTG on Android.
  TsplPrinter.usb({
    required int vendorId,
    required int productId,
    TextRasterizer? rasterizer,
    PrintQueue? queue,
  })  : assert(vendorId > 0, 'vendorId must be a positive integer.'),
        assert(productId > 0, 'productId must be a positive integer.'),
        transport = UsbTransport(
          vendorId: vendorId,
          productId: productId,
          maxChunkSize: 4096,
        ),
        encoder = TsplEncoder(rasterizer: rasterizer ?? const FakeRasterizer()),
        queue = queue ?? PrintQueue();

  /// Custom constructor allowing injection of any [PrinterTransport] (e.g. [FakeTransport]).
  TsplPrinter.custom(
    this.transport, {
    TextRasterizer? rasterizer,
    PrintQueue? queue,
  })  : encoder = TsplEncoder(rasterizer: rasterizer ?? const FakeRasterizer()),
        queue = queue ?? PrintQueue();

  /// The active communication transport (WiFi, Bluetooth, USB, or Fake).
  final PrinterTransport transport;

  /// TSPL compiler translating label models into binary commands.
  final TsplEncoder encoder;

  /// Serial FIFO queue ensuring label jobs do not interleave.
  final PrintQueue queue;

  /// Connection state stream.
  Stream<PosConnectionState> get state => transport.state;

  /// The current connection state.
  PosConnectionState get currentState => transport.currentState;

  /// Compiles and prints [label] through the serial FIFO queue.
  Future<Result<void>> print(
    TsplLabel label, {
    int maxRetries = 3,
    List<Duration> retryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  }) {
    return queue.enqueue<void>(
      () => _executePrintJob(label),
      maxRetries: maxRetries,
      retryDelays: retryDelays,
    );
  }

  /// Sends a `FORMFEED` command to feed the paper to the next label boundary.
  Future<Result<void>> formFeed() => _sendRawCommand('FORMFEED\r\n');

  /// Calibrates the printer's label gap sensor (`GAPDETECT`).
  Future<Result<void>> calibrate() => _sendRawCommand('GAPDETECT\r\n');

  /// Issues a hardware cut command (`CUT`).
  Future<Result<void>> cut() => _sendRawCommand('CUT\r\n');

  /// Internal worker executing a single label print job with auto-connect and pacing.
  Future<Result<void>> _executePrintJob(TsplLabel label) async {
    // 1. Ensure transport is connected
    if (transport.currentState != PosConnectionState.connected) {
      PosLogger.info('Connecting to TSPL label printer...');
      final connectRes = await transport.connect();
      if (connectRes.isError) {
        return connectRes;
      }
    }

    // 2. Encode label to TSPL binary command bytes
    final bytes = await encoder.encode(label);
    PosLogger.verbose('Transmitting ${bytes.length} TSPL bytes to label printer...');

    // 3. Write data in chunks respecting transport MTU and chunkDelay
    final maxChunk = transport.maxChunkSize;
    final pacingDelay = transport.chunkDelay;

    if (bytes.length <= maxChunk) {
      return transport.write(bytes);
    }

    var offset = 0;
    while (offset < bytes.length) {
      final chunkSize = (bytes.length - offset).clamp(0, maxChunk);
      final chunk = Uint8List.sublistView(bytes, offset, offset + chunkSize);
      final writeRes = await transport.write(chunk);
      if (writeRes.isError) {
        return writeRes;
      }
      offset += chunkSize;
      if (offset < bytes.length && pacingDelay > Duration.zero) {
        await Future<void>.delayed(pacingDelay);
      }
    }

    return const Result.ok(null);
  }

  /// Sends a raw TSPL ASCII command string.
  Future<Result<void>> _sendRawCommand(String command) async {
    if (transport.currentState != PosConnectionState.connected) {
      final connectRes = await transport.connect();
      if (connectRes.isError) return connectRes;
    }
    return transport.write(Uint8List.fromList(utf8.encode(command)));
  }

  /// Disconnects the printer transport and clears pending jobs.
  Future<void> close() async {
    queue.clear();
    await transport.disconnect();
  }
}
