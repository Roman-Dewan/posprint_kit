import 'dart:typed_data';

import '../core/logger.dart';
import '../core/printer_profile.dart';
import '../core/receipt.dart';
import '../core/receipt_encoder.dart';
import '../core/result.dart';
import '../core/text_rasterizer.dart';
import '../transports/printer_transport.dart';
import 'print_queue.dart';

/// Coordinates print job sequencing, chunking, connection lifecycle, and retry handling.
class PrinterManager {
  PrinterManager({
    required this.transport,
    this.profile = PrinterProfile.generic80,
    TextRasterizer? rasterizer,
    PrintQueue? queue,
  })  : rasterizer = rasterizer ?? const FakeRasterizer(),
        queue = queue ?? PrintQueue();

  /// The active physical or virtual transport medium.
  final PrinterTransport transport;

  /// Hardware capabilities and resolution specifications of the target printer.
  final PrinterProfile profile;

  /// Interface for rasterizing text and complex layout rows.
  final TextRasterizer rasterizer;

  /// Serial FIFO queue ensuring jobs do not interleave.
  final PrintQueue queue;

  /// Broadcast stream of connection state changes.
  Stream<PosConnectionState> get state => transport.state;

  /// The active connection state of the printer transport.
  PosConnectionState get currentState => transport.currentState;

  /// Submits [receipt] to the serial queue to be printed.
  ///
  /// Guarantees that multiple concurrent calls to `print()` execute sequentially
  /// and completely without interleaving lines on paper.
  Future<Result<void>> print(
    Receipt receipt, {
    int maxRetries = 3,
    List<Duration> retryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  }) {
    return queue.enqueue<void>(
      () => _executePrintJob(receipt),
      maxRetries: maxRetries,
      retryDelays: retryDelays,
    );
  }

  Future<Result<void>> _executePrintJob(Receipt receipt) async {
    // 1. Ensure transport is connected
    if (transport.currentState != PosConnectionState.connected) {
      PosLogger.info('Connecting to printer before job execution...');
      final connectRes = await transport.connect();
      if (connectRes.isError) {
        return connectRes;
      }
    }

    // 2. Encode receipt to ESC/POS bytes
    final encoder = ReceiptEncoder(profile, rasterizer);
    final encodeRes = await encoder.encode(receipt);
    if (encodeRes.isError) {
      return Result.error(encodeRes.errorOrNull!);
    }

    final bytes = encodeRes.valueOrNull!;
    PosLogger.verbose('Transmitting ${bytes.length} bytes to printer...');

    // 3. Write data in chunks respecting transport MTU / maxChunkSize
    final maxChunk = transport.maxChunkSize;
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
    }

    return const Result.ok(null);
  }

  /// Disconnects the printer transport and empties pending jobs.
  Future<void> close() async {
    queue.clear();
    await transport.disconnect();
  }
}

