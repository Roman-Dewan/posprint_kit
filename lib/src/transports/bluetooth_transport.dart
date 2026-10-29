import 'dart:async';
import 'package:flutter/services.dart';

import '../core/logger.dart';
import '../core/result.dart';
import 'printer_transport.dart';

/// Represents a discovered or paired Bluetooth device.
class BluetoothDevice {
  const BluetoothDevice({
    required this.name,
    required this.address,
  });

  /// The user-visible name or model string (e.g. "XP-58").
  final String name;

  /// The MAC address of the device (e.g. "00:11:22:33:44:55").
  final String address;

  @override
  String toString() => '$name ($address)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

/// Communication transport for Bluetooth Classic thermal printers on Android.
///
/// Communicates over standard RFCOMM SPP (Serial Port Profile).
class BluetoothTransport implements PrinterTransport {
  BluetoothTransport(
    this.address, {
    this.maxChunkSize = 512,
  }) : assert(address.trim().isNotEmpty, 'Bluetooth MAC address cannot be empty.');

  /// The MAC address of the target Bluetooth printer.
  final String address;

  @override
  final int maxChunkSize;

  static const MethodChannel _channel = MethodChannel('posprint_kit');

  final _stateController = StreamController<PosConnectionState>.broadcast(sync: true);
  PosConnectionState _currentState = PosConnectionState.disconnected;

  @override
  Stream<PosConnectionState> get state => _stateController.stream;

  @override
  PosConnectionState get currentState => _currentState;

  /// Retrieves a list of all bonded (paired) Bluetooth devices on this Android device.
  static Future<Result<List<BluetoothDevice>>> listPairedDevices() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeListMethod<dynamic>('bt.listPaired');

      final devices = <BluetoothDevice>[];
      if (rawList != null) {
        for (final item in rawList) {
          if (item is Map) {
            final name = item['name']?.toString() ?? 'Bluetooth Printer';
            final addr = item['address']?.toString() ?? '';
            if (addr.isNotEmpty) {
              devices.add(BluetoothDevice(name: name, address: addr));
            }
          }
        }
      }

      return Result.ok(devices);
    } on PlatformException catch (e) {
      PosLogger.error('Failed to list paired Bluetooth devices: ${e.message}');
      return Result.error(_mapPlatformError(e));
    } catch (e) {
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  /// Explicitly requests Android OS runtime Bluetooth permissions
  /// (`BLUETOOTH_CONNECT` and `BLUETOOTH_SCAN` on Android 12+).
  static Future<Result<bool>> requestPermission() async {
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('bt.requestPermission');
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
      PosLogger.info('Connecting to Bluetooth printer ($address)...');
      final bool? success = await _channel.invokeMethod<bool>(
        'bt.connect',
        {'address': address},
      );

      if (success == true) {
        _updateState(PosConnectionState.connected);
        PosLogger.info('Connected to Bluetooth printer ($address).');
        return const Result.ok(null);
      } else {
        _updateState(PosConnectionState.disconnected);
        return Result.error(
          PrinterError(
            PrinterErrorCode.connectionFailed,
            message: 'Could not connect to Bluetooth device $address.',
            hint: 'Ensure the printer is powered on, paired in Android Bluetooth settings, '
                'and within 10 meters of this device.',
          ),
        );
      }
    } on PlatformException catch (e) {
      _updateState(PosConnectionState.disconnected);
      PosLogger.error('Bluetooth connect error: ${e.message}');
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
        'bt.write',
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
      PosLogger.error('Bluetooth write error: ${e.message}');
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
      await _channel.invokeMethod<void>('bt.disconnect');
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
        return PrinterError.permissionDenied;
      case 'BLUETOOTH_DISABLED':
        return const PrinterError(
          PrinterErrorCode.connectionFailed,
          message: 'Bluetooth is turned off on this device.',
          hint: 'Enable Bluetooth in device settings and make sure the printer is paired.',
        );
      case 'BLUETOOTH_UNAVAILABLE':
        return const PrinterError(
          PrinterErrorCode.unsupportedPlatform,
          message: 'Bluetooth hardware is not available on this device.',
          hint: 'Use WiFi or USB connection instead.',
        );
      case 'CONNECTION_LOST':
      case 'WRITE_FAILED':
        return PrinterError.connectionLost;
      case 'CONNECTION_FAILED':
        return PrinterError(
          PrinterErrorCode.connectionFailed,
          message: e.message ?? 'Bluetooth connection failed.',
          hint: 'Ensure printer is turned on and paired.',
        );
      default:
        return PrinterError.unknown(detail: e.message);
    }
  }
}

