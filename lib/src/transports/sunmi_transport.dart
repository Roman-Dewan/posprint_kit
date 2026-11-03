import 'dart:async';
import 'package:flutter/services.dart';

import '../core/logger.dart';
import '../core/ops.dart';
import '../core/printer_profile.dart';
import '../core/receipt.dart';
import '../core/result.dart';
import 'printer_transport.dart';

/// Communication transport for built-in thermal receipt printers on Sunmi Android POS terminals
/// (e.g. Sunmi D3, V2, V2s, T2).
///
/// Communicates directly with the Sunmi Printer Service via Sunmi's PrinterX SDK and
/// executes standard ESC/POS bytes natively.
class SunmiTransport implements PrinterTransport {
  SunmiTransport({
    this.maxChunkSize = 16384,
    this.chunkDelay = Duration.zero,
  });

  @override
  final int maxChunkSize;

  @override
  final Duration chunkDelay;

  static const MethodChannel _channel = MethodChannel('posprint_kit');

  final _stateController =
      StreamController<PosConnectionState>.broadcast(sync: true);
  PosConnectionState _currentState = PosConnectionState.disconnected;

  @override
  Stream<PosConnectionState> get state => _stateController.stream;

  @override
  PosConnectionState get currentState => _currentState;

  /// Returns `true` if the current Android device is manufactured by Sunmi.
  static Future<bool> isSunmiDevice() async {
    try {
      final bool? isSunmi =
          await _channel.invokeMethod<bool>('sunmi.isSupported');
      return isSunmi == true;
    } catch (_) {
      return false;
    }
  }

  /// Queries the physical paper roll width in millimeters from the Sunmi Printer Service
  /// (returns `80` on desktop terminals like Sunmi D3, or `58` on mobile handhelds like Sunmi V2).
  static Future<int> getPaperWidth() async {
    try {
      final int? width =
          await _channel.invokeMethod<int>('sunmi.getPaperWidth');
      return width ?? 80;
    } catch (_) {
      return 80;
    }
  }

  /// Queries the real-time operational status from the Sunmi built-in printer
  /// (e.g. `'NORMAL'`, `'COVER_OPEN'`, `'OUT_OF_PAPER'`).
  static Future<Result<String>> getStatus() async {
    try {
      final String? status =
          await _channel.invokeMethod<String>('sunmi.getStatus');
      return Result.ok(status ?? 'UNKNOWN');
    } on PlatformException catch (e) {
      PosLogger.error('Failed to get Sunmi printer status: ${e.message}');
      return Result.error(_mapPlatformError(e));
    } catch (e) {
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  /// Triggers the cash drawer kick-out via Sunmi's cash drawer API and RJ12 ESC/POS pulses.
  static Future<Result<void>> openDrawer() async {
    try {
      await _channel.invokeMethod<void>('sunmi.openDrawer');
      return const Result.ok(null);
    } on PlatformException catch (e) {
      PosLogger.error('Failed to open Sunmi cash drawer: ${e.message}');
      return Result.error(_mapPlatformError(e));
    } catch (e) {
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  /// Triggers the cash drawer kick-out on this connected Sunmi terminal.
  Future<Result<void>> kickDrawer() => openDrawer();

  @override
  Future<Result<void>> connect() async {
    if (_currentState == PosConnectionState.connected) {
      return const Result.ok(null);
    }

    _updateState(PosConnectionState.connecting);

    try {
      PosLogger.info('Connecting to Sunmi built-in printer service...');
      final bool? success =
          await _channel.invokeMethod<bool>('sunmi.connect');

      if (success == true) {
        _updateState(PosConnectionState.connected);
        PosLogger.info('Connected to Sunmi built-in printer.');
        return const Result.ok(null);
      } else {
        _updateState(PosConnectionState.disconnected);
        return const Result.error(
          PrinterError(
            PrinterErrorCode.connectionFailed,
            message: 'Could not connect to Sunmi built-in printer service.',
            hint:
                'Ensure your app is running on a Sunmi POS terminal with Sunmi Printer Service enabled.',
          ),
        );
      }
    } on PlatformException catch (e) {
      _updateState(PosConnectionState.disconnected);
      PosLogger.error('Sunmi connect error: ${e.message}');
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

    if (bytes.isEmpty) {
      return const Result.ok(null);
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'sunmi.write',
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
      PosLogger.error('Sunmi write error: ${e.message}');
      return Result.error(_mapPlatformError(e));
    } catch (e) {
      await disconnect();
      return Result.error(PrinterError.unknown(detail: e.toString()));
    }
  }

  /// Prints a structured [Receipt] using Sunmi's native LineApi,
  /// executing fonts, alignments, and dashed dividers natively on Sunmi thermal hardware.
  Future<Result<void>> printReceipt(
    Receipt receipt, {
    PrinterProfile? profile,
  }) async {
    if (_currentState != PosConnectionState.connected) {
      final connectRes = await connect();
      if (connectRes.isError) {
        return connectRes;
      }
    }

    final ops = <Map<String, dynamic>>[];
    for (final op in receipt.ops) {
      switch (op) {
        case TextOp(
            :final text,
            :final align,
            :final bold,
            :final size,
            :final style
          ):
          final int effectiveFontSize;
          if (style.fontSize != 24) {
            effectiveFontSize = style.fontSize.round();
          } else {
            effectiveFontSize = switch (size) {
              TextSize.doubleSize => 36,
              TextSize.doubleWidth || TextSize.doubleHeight => 30,
              TextSize.normal => 24,
            };
          }
          ops.add({
            'type': 'text',
            'text': text,
            'align': align.name,
            'bold': bold || style.bold,
            'fontSize': effectiveFontSize,
          });

        case DividerOp(:final character):
          ops.add({
            'type': 'divider',
            'character': character,
          });

        case RowOp(
            :final left,
            :final right,
            :final bold,
            :final style
          ):
          final int effectiveFontSize =
              style.fontSize != 24 ? style.fontSize.round() : 24;
          ops.add({
            'type': 'row',
            'left': left,
            'right': right,
            'bold': bold || style.bold,
            'fontSize': effectiveFontSize,
          });

        case ColumnsOp(:final columns, :final bold):
          final int effectiveFontSize = columns.isNotEmpty &&
                  columns.first.style.fontSize != 24
              ? columns.first.style.fontSize.round()
              : 24;
          ops.add({
            'type': 'columns',
            'texts': columns.map((c) => c.text).toList(),
            'widths': columns.map((c) => c.width).toList(),
            'aligns': columns.map((c) => c.align.name).toList(),
            'bold': bold,
            'fontSize': effectiveFontSize,
          });

        case QrOp(:final data, :final size, :final align):
          ops.add({
            'type': 'qr',
            'data': data,
            'size': size,
            'align': align.name,
          });

        case BarcodeOp(:final data, :final height):
          ops.add({
            'type': 'barcode',
            'data': data,
            'height': height,
            'align': 'center',
          });

        case FeedOp(:final lines):
          ops.add({
            'type': 'feed',
            'lines': lines,
          });

        case CutOp():
          ops.add({'type': 'cut'});

        case CashDrawerOp():
          ops.add({'type': 'drawer'});

        case RawBytesOp():
        case ImageOp():
          break;
      }
    }

    final is58mm = profile != null && profile.dotsWidth <= 384;

    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'sunmi.printReceipt',
        {'ops': ops, 'is58mm': is58mm},
      );

      if (success == true) {
        return const Result.ok(null);
      } else {
        await disconnect();
        return const Result.error(PrinterError.connectionLost);
      }
    } on PlatformException catch (e) {
      await disconnect();
      PosLogger.error('Sunmi printReceipt error: ${e.message}');
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
      await _channel.invokeMethod<void>('sunmi.disconnect');
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
      case 'NOT_SUNMI_DEVICE':
      case 'SUNMI_UNAVAILABLE':
        return const PrinterError(
          PrinterErrorCode.unsupportedPlatform,
          message: 'Sunmi built-in printer is not available on this device.',
          hint:
              'This transport is only supported on Sunmi POS terminals (e.g. Sunmi D3, V2, T2). For external printers, use WiFi, Bluetooth, or USB.',
        );
      case 'NO_PRINTER':
        return const PrinterError(
          PrinterErrorCode.connectionFailed,
          message: 'No built-in printer detected on this Sunmi terminal.',
          hint:
              'Ensure this Sunmi model has an integrated thermal receipt printer hardware module.',
        );
      case 'CONNECTION_TIMEOUT':
      case 'SUNMI_INIT_FAILED':
        return PrinterError(
          PrinterErrorCode.connectionFailed,
          message: e.message ?? 'Failed to connect to Sunmi Printer Service.',
          hint:
              'Verify that Sunmi Printer Service is running in Sunmi Settings -> System Updates.',
        );
      case 'NOT_CONNECTED':
      case 'WRITE_FAILED':
        return PrinterError.connectionLost;
      case 'DRAWER_FAILED':
      case 'DRAWER_UNAVAILABLE':
        return PrinterError(
          PrinterErrorCode.unknown,
          message: e.message ?? 'Failed to kick Sunmi cash drawer.',
          hint:
              'Ensure the cash drawer RJ12 cable is firmly plugged into the RJ12 drawer port on the Sunmi terminal.',
        );
      default:
        return PrinterError.unknown(detail: e.message);
    }
  }
}

/// Convenient alias for [SunmiTransport] when communicating with built-in POS terminal printers.
typedef InbuiltTransport = SunmiTransport;
