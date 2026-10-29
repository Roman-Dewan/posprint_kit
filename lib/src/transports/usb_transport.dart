import 'dart:async';
import 'package:flutter/services.dart';

import '../core/logger.dart';
import '../core/result.dart';
import 'printer_transport.dart';

/// Represents a connected USB device on Android.
class UsbDevice {
  const UsbDevice({
    required this.vendorId,
    required this.productId,
    required this.name,
    this.deviceName,
    this.hasPermission = false,
  });

  /// The USB vendor identifier.
  final int vendorId;

  /// The USB product identifier.
  final int productId;

  /// Human-readable device product name.
  final String name;

  /// Internal device path (e.g. `/dev/bus/usb/001/002`).
  final String? deviceName;

  /// Whether USB communication permission has already been granted by the user.
  final bool hasPermission;

  @override
  String toString() => '$name (VID: $vendorId, PID: $productId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsbDevice &&
          runtimeType == other.runtimeType &&
          vendorId == other.vendorId &&
          productId == other.productId;

  @override
  int get hashCode => Object.hash(vendorId, productId);
}

/// Communication transport for USB thermal receipt printers on Android (OTG).
class UsbTransport implements PrinterTransport {
  UsbTransport({
    required this.vendorId,
    required this.productId,
    this.maxChunkSize = 4096,
  })  : assert(vendorId > 0, 'vendorId must be a positive integer.'),
        assert(productId > 0, 'productId must be a positive integer.');

  /// Target printer USB vendor ID.
  final int vendorId;

  /// Target printer USB product ID.
  final int productId;

  @override
  final int maxChunkSize;

  static const MethodChannel _channel = MethodChannel('posprint_kit');

  final _stateController = StreamController<PosConnectionState>.broadcast(sync: true);
  PosConnectionState _currentState = PosConnectionState.disconnected;

  @override
  Stream<PosConnectionState> get state => _stateController.stream;

  @override
  PosConnectionState get currentState => _currentState;

  /// Discovers all currently plugged-in USB devices.
  static Future<Result<List<UsbDevice>>> listDevices() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeListMethod<dynamic>('usb.list');

      final devices = <UsbDevice>[];
      if (rawList != null) {
        for (final item in rawList) {
          if (item is Map) {
            final vid = item['vendorId'] as int? ?? 0;
            final pid = item['productId'] as int? ?? 0;
            final name = item['name']?.toString() ?? 'USB Printer';
            final devName = item['deviceName']?.toString();
            final hasPerm = item['hasPermission'] as bool? ?? false;

            if (vid > 0 && pid > 0) {
              devices.add(
                UsbDevice(
                  vendorId: vid,
                  productId: pid,
                  name: name,
                  deviceName: devName,
                  hasPermission: hasPerm,
                ),
              );
            }
          }
        }
      }

      return Result.ok(devices);
    } on PlatformException catch (e) {
      PosLogger.error('Failed to list USB devices: ${e.message}');
      return Result.error(_mapPlatformError(e));
    } catch (e) {
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  /// Explicitly requests Android OS permission to interact with this USB device.
  static Future<Result<bool>> requestPermission(
    int vendorId,
    int productId,
  ) async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>(
        'usb.requestPermission',
        {'vendorId': vendorId, 'productId': productId},
      );
      return Result.ok(granted == true);
    } on PlatformException catch (e) {
      return Result.error(_mapPlatformError(e));
    } catch (e) {
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  @override
  Future<Result<void>> connect() async {
    if (_currentState == PosConnectionState.connected) {
      return const Result.ok(null);
    }

    _updateState(PosConnectionState.connecting);

    try {
      PosLogger.info('Opening USB connection to VID:$vendorId, PID:$productId...');
      final bool? success = await _channel.invokeMethod<bool>(
        'usb.connect',
        {'vendorId': vendorId, 'productId': productId},
      );

      if (success == true) {
        _updateState(PosConnectionState.connected);
        PosLogger.info('Connected to USB printer.');
        return const Result.ok(null);
      } else {
        _updateState(PosConnectionState.disconnected);
        return Result.error(
          PrinterError(
            PrinterErrorCode.connectionFailed,
            message: 'Could not connect to USB printer (VID: $vendorId, PID: $productId).',
            hint: 'Ensure the printer is plugged into your device with an OTG cable and powered on.',
          ),
        );
      }
    } on PlatformException catch (e) {
      _updateState(PosConnectionState.disconnected);
      PosLogger.error('USB connect error: ${e.message}');
      return Result.error(_mapPlatformError(e));
    } catch (e) {
      _updateState(PosConnectionState.disconnected);
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  @override
  Future<Result<void>> write(Uint8List bytes) async {
    if (_currentState != PosConnectionState.connected) {
      final connectRes = await connect();
      if (connectRes.isError) {
        return connectRes;
      }
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'usb.write',
        {'bytes': bytes},
      );

      if (success == true) {
        return const Result.ok(null);
      } else {
        await disconnect();
        return const Result.error(PrinterError.connectionLost);
      }
    } on PlatformException catch (e) {
      await disconnect();
      PosLogger.error('USB write error: ${e.message}');
      return Result.error(_mapPlatformError(e));
    } catch (e) {
      await disconnect();
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  @override
  Future<Result<Uint8List?>> read({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return const Result.ok(null);
  }

  @override
  Future<void> disconnect() async {
    if (_currentState == PosConnectionState.disconnected) {
      return;
    }

    _updateState(PosConnectionState.disconnecting);
    try {
      await _channel.invokeMethod<void>('usb.disconnect');
    } catch (_) {}
    _updateState(PosConnectionState.disconnected);
  }

  void _updateState(PosConnectionState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  static PrinterError _mapPlatformError(PlatformException e) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        return const PrinterError(
          PrinterErrorCode.permissionDenied,
          message: 'USB permission was denied for this printer.',
          hint: 'Accept the USB device permission dialog when prompted on your Android screen.',
        );
      case 'DEVICE_NOT_FOUND':
        return const PrinterError(
          PrinterErrorCode.connectionFailed,
          message: 'USB printer device not found.',
          hint: 'Check that the USB cable is securely connected and that the printer is turned on.',
        );
      case 'NO_ENDPOINT':
        return const PrinterError(
          PrinterErrorCode.connectionFailed,
          message: 'No bulk-transfer print endpoint found on this USB device.',
          hint: 'Verify that the USB cable connects directly to the printer interface.',
        );
      case 'CONNECTION_LOST':
      case 'WRITE_FAILED':
        return PrinterError.connectionLost;
      case 'CONNECTION_FAILED':
        return PrinterError(
          PrinterErrorCode.connectionFailed,
          message: e.message ?? 'Failed to open USB connection.',
          hint: 'Check that the USB OTG adapter is compatible and securely attached.',
        );
      default:
        return PrinterError.unknown(detail: e.message);
    }
  }
}

