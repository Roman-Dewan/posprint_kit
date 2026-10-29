import 'dart:typed_data';

import '../core/result.dart';

/// Connection states for printer transports.
enum PosConnectionState {
  /// No active connection to the printer.
  disconnected,

  /// In the process of opening a connection.
  connecting,

  /// Actively connected and ready to send data.
  connected,

  /// In the process of closing the connection.
  disconnecting,
}

/// Abstract communication medium for sending bytes to and receiving status from a thermal printer.
///
/// Implementations handle network TCP sockets, Bluetooth RFCOMM, USB bulk endpoints,
/// or in-memory fakes.
abstract class PrinterTransport {
  /// Opens a communication channel to the printer.
  ///
  /// Returns [Result.ok] on success, or a descriptive [PrinterError] on failure.
  Future<Result<void>> connect();

  /// Transmits raw ESC/POS [bytes] to the printer.
  ///
  /// For transports with small buffers (like Bluetooth SPP or BLE), the caller or manager
  /// splits data according to [maxChunkSize].
  Future<Result<void>> write(Uint8List bytes);

  /// Reads incoming bytes from the printer with an optional [timeout].
  ///
  /// Returns `null` if no data arrived before timeout.
  Future<Result<Uint8List?>> read({Duration timeout = const Duration(seconds: 3)});

  /// Closes the active connection and releases system resources.
  Future<void> disconnect();

  /// A broadcast stream notifying listeners of [PosConnectionState] changes.
  Stream<PosConnectionState> get state;

  /// The current connection state of this transport.
  PosConnectionState get currentState;

  /// Maximum byte payload that can be safely sent in a single transport write.
  ///
  /// Typical values: 65,536 bytes for TCP network sockets, 512–1024 bytes for
  /// Bluetooth Classic, 20–512 bytes for BLE depending on negotiated MTU.
  int get maxChunkSize;
}

