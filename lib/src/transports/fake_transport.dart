import 'dart:async';
import 'dart:typed_data';

import '../core/result.dart';
import 'printer_transport.dart';

/// An in-memory, deterministic implementation of [PrinterTransport] for unit tests
/// and UI preview environments.
///
/// Records all transmitted bytes, supports artificial delays, and allows failure injection.
class FakeTransport implements PrinterTransport {
  FakeTransport({
    this.maxChunkSize = 65536,
    this.connectDelay,
    this.writeDelay,
  });

  @override
  final int maxChunkSize;

  /// Optional artificial delay applied during [connect].
  final Duration? connectDelay;

  /// Optional artificial delay applied during [write].
  final Duration? writeDelay;

  final _stateController = StreamController<PosConnectionState>.broadcast();
  PosConnectionState _currentState = PosConnectionState.disconnected;

  final List<Uint8List> _writtenChunks = [];

  /// Injected failure for the next [connect] call.
  PrinterError? nextConnectError;

  /// Injected persistent failure for all [connect] calls.
  PrinterError? persistentConnectError;

  /// Injected failure for the next [write] call.
  PrinterError? nextWriteError;

  /// Injected persistent failure for all [write] calls.
  PrinterError? persistentWriteError;

  /// Number of successful writes before failing all subsequent writes.
  int? failAfterWritesCount;
  var _successfulWritesCount = 0;

  @override
  Stream<PosConnectionState> get state => _stateController.stream;

  @override
  PosConnectionState get currentState => _currentState;

  /// All byte chunks received through [write] in order.
  List<Uint8List> get writtenChunks => List.unmodifiable(_writtenChunks);

  /// All written bytes concatenated into a single [Uint8List].
  Uint8List get recordedBytes {
    final builder = BytesBuilder(copy: false);
    for (final chunk in _writtenChunks) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Clears all recorded written chunks.
  void clearRecordedBytes() {
    _writtenChunks.clear();
    _successfulWritesCount = 0;
  }

  @override
  Future<Result<void>> connect() async {
    if (connectDelay != null) {
      await Future<void>.delayed(connectDelay!);
    }

    _updateState(PosConnectionState.connecting);

    if (persistentConnectError != null) {
      _updateState(PosConnectionState.disconnected);
      return Result.error(persistentConnectError!);
    }

    if (nextConnectError != null) {
      final error = nextConnectError!;
      nextConnectError = null;
      _updateState(PosConnectionState.disconnected);
      return Result.error(error);
    }

    _updateState(PosConnectionState.connected);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> write(Uint8List bytes) async {
    if (_currentState != PosConnectionState.connected) {
      // OLD: return Result.error(PrinterError.connectionLost);
      return const Result.error(PrinterError.connectionLost);
    }

    if (writeDelay != null) {
      await Future<void>.delayed(writeDelay!);
    }

    if (persistentWriteError != null) {
      return Result.error(persistentWriteError!);
    }

    if (nextWriteError != null) {
      final error = nextWriteError!;
      nextWriteError = null;
      return Result.error(error);
    }

    if (failAfterWritesCount != null &&
        _successfulWritesCount >= failAfterWritesCount!) {
      // OLD: return Result.error(PrinterError.connectionLost);
      return const Result.error(PrinterError.connectionLost);
    }

    _writtenChunks.add(Uint8List.fromList(bytes));
    _successfulWritesCount++;
    return const Result.ok(null);
  }

  @override
  Future<Result<Uint8List?>> read({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return const Result.ok(null);
  }

  @override
  Future<void> disconnect() async {
    _updateState(PosConnectionState.disconnecting);
    _updateState(PosConnectionState.disconnected);
  }

  /// Disposes stream controllers.
  void dispose() {
    _stateController.close();
  }

  void _updateState(PosConnectionState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
