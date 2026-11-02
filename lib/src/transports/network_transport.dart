import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/logger.dart';
import '../core/result.dart';
import '../discovery/printer_discovery.dart';
import 'printer_transport.dart';

export '../discovery/printer_discovery.dart'
    show NetworkDevice, NetworkDiscovery;

/// Communication transport for network-connected thermal receipt printers over raw TCP.
///
/// Most network printers (Epson, Star, Bixolon, Xprinter) listen for raw ESC/POS bytes
/// on TCP port 9100 (standard AppSocket / JetDirect protocol).
///
/// Pure Dart: does not import Flutter or dart:ui.
class NetworkTransport implements PrinterTransport {
  NetworkTransport(
    this.host, {
    this.port = 9100,
    this.timeout = const Duration(seconds: 5),
    this.maxChunkSize = 65536,
  })  : assert(host.trim().isNotEmpty, 'host cannot be empty.'),
        assert(port > 0 && port <= 65535, 'port must be between 1 and 65535.');

  /// Creates a [NetworkTransport] connecting to a discovered [NetworkDevice].
  factory NetworkTransport.fromDevice(
    NetworkDevice device, {
    Duration timeout = const Duration(seconds: 5),
    int maxChunkSize = 65536,
  }) =>
      NetworkTransport(
        device.ip,
        port: device.port,
        timeout: timeout,
        maxChunkSize: maxChunkSize,
      );

  /// Discovers thermal printers on the local WiFi/LAN network by scanning subnet IP addresses.
  ///
  /// - [subnet]: Optional subnet prefix (e.g. `'192.168.1'`). If omitted, auto-detects
  ///   active IPv4 subnets from local network interfaces.
  /// - [port]: The TCP port to probe (default `9100`).
  /// - [ports]: Optional list of alternative ports to probe. Defaults to `[port]`.
  /// - [timeout]: Connection timeout per IP address (default 300 ms).
  /// - [batchSize]: Concurrency level when probing IPs (default 32 parallel probes).
  /// - [onDeviceFound]: Optional callback triggered immediately whenever a printer is discovered.
  /// - [probeHardware]: If true, queries the printer over TCP with ESC/POS hardware identification
  ///   commands (`GS I 67` / `GS I 2`) to resolve model name.
  static Future<Result<List<NetworkDevice>>> discoverDevices({
    String? subnet,
    int port = 9100,
    List<int>? ports,
    Duration timeout = const Duration(milliseconds: 300),
    int batchSize = 32,
    void Function(NetworkDevice device)? onDeviceFound,
    bool probeHardware = true,
  }) =>
      NetworkDiscovery.discoverPrinters(
        subnet: subnet,
        port: port,
        ports: ports,
        timeout: timeout,
        batchSize: batchSize,
        onDeviceFound: onDeviceFound,
        probeHardware: probeHardware,
      );

  /// Lists discovered network printers on the local WiFi/LAN network.
  ///
  /// Convenience alias matching [UsbTransport.listDevices] and [BluetoothTransport.listPairedDevices].
  static Future<Result<List<NetworkDevice>>> listDevices({
    String? subnet,
    int port = 9100,
    Duration timeout = const Duration(milliseconds: 300),
  }) =>
      discoverDevices(subnet: subnet, port: port, timeout: timeout);

  /// Target printer IP address or hostname.
  final String host;

  /// Target TCP port (standard is 9100).
  final int port;

  /// Connection establishment timeout (defaults to 5 seconds to prevent hanging the UI).
  final Duration timeout;

  @override
  final int maxChunkSize;

  @override
  Duration get chunkDelay => Duration.zero;

  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSubscription;

  final _stateController = StreamController<PosConnectionState>.broadcast();
  PosConnectionState _currentState = PosConnectionState.disconnected;

  @override
  Stream<PosConnectionState> get state => _stateController.stream;

  @override
  PosConnectionState get currentState => _currentState;

  @override
  Future<Result<void>> connect() async {
    if (_currentState == PosConnectionState.connected && _socket != null) {
      return const Result.ok(null);
    }

    _updateState(PosConnectionState.connecting);

    try {
      PosLogger.info(
          'Connecting to printer at $host:$port (timeout: ${timeout.inSeconds}s)...');
      _socket = await Socket.connect(host, port, timeout: timeout);

      _socketSubscription = _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      _updateState(PosConnectionState.connected);
      PosLogger.info('Connected to printer at $host:$port.');
      return const Result.ok(null);
    } on SocketException catch (e) {
      PosLogger.error(
          'Failed to connect to printer at $host:$port: ${e.message}');
      _cleanupSocket();
      _updateState(PosConnectionState.disconnected);
      return Result.error(
          PrinterError.connectionFailed(host: host, port: port));
    } on TimeoutException {
      PosLogger.error('Connection to printer at $host:$port timed out.');
      _cleanupSocket();
      _updateState(PosConnectionState.disconnected);
      return Result.error(PrinterError.timeout(host: host, duration: timeout));
    } catch (e) {
      PosLogger.error('Unexpected error connecting to $host:$port: $e');
      _cleanupSocket();
      _updateState(PosConnectionState.disconnected);
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  @override
  Future<Result<void>> write(Uint8List bytes) async {
    if (_currentState != PosConnectionState.connected || _socket == null) {
      // Auto-reconnect if socket was dropped
      PosLogger.info('Printer disconnected; reconnecting before write...');
      final connectRes = await connect();
      if (connectRes.isError) {
        return connectRes;
      }
    }

    try {
      _socket!.add(bytes);
      await _socket!.flush();
      return const Result.ok(null);
    } on SocketException catch (e) {
      PosLogger.error(
          'SocketException during write to $host:$port: ${e.message}');
      await disconnect();
      return const Result.error(PrinterError.connectionLost);
    } catch (e) {
      PosLogger.error('Unexpected write failure to $host:$port: $e');
      await disconnect();
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  @override
  Future<Result<Uint8List?>> read({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    // Basic read placeholder; full status querying handled via DLE EOT
    return const Result.ok(null);
  }

  @override
  Future<void> disconnect() async {
    if (_currentState == PosConnectionState.disconnected) {
      return;
    }

    _updateState(PosConnectionState.disconnecting);
    _cleanupSocket();
    _updateState(PosConnectionState.disconnected);
    PosLogger.info('Disconnected from printer at $host:$port.');
  }

  void _cleanupSocket() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
  }

  void _onData(Uint8List data) {
    PosLogger.verbose('Received ${data.length} bytes from printer.');
  }

  void _onError(Object error) {
    PosLogger.warning(
        'Socket error on printer connection to $host:$port: $error');
    disconnect();
  }

  void _onDone() {
    PosLogger.info('Printer at $host:$port closed connection.');
    disconnect();
  }

  void _updateState(PosConnectionState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Closes internal stream controllers.
  void dispose() {
    disconnect();
    _stateController.close();
  }
}
