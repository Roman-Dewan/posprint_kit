import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/logger.dart';
import '../core/result.dart';

/// Represents a discovered network/WiFi thermal printer.
class NetworkDevice {
  const NetworkDevice({
    required this.ip,
    required this.port,
    required this.name,
    required this.model,
    this.hostName,
  });

  /// The IPv4 address of the printer (e.g. "192.168.1.105").
  final String ip;

  /// The raw TCP port of the printer (standard is 9100).
  final int port;

  /// Human-readable printer name (e.g. "EPSON TM-T20III" or "Network Printer (192.168.1.105)").
  final String name;

  /// The printer model string (e.g. "TM-T20III", "XP-80", or "ESC/POS Network Printer").
  final String model;

  /// The resolved DNS hostname, if available (e.g. "EPSON_PRINTER.local").
  final String? hostName;

  @override
  String toString() => '$name ($model - $ip:$port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkDevice &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => Object.hash(ip, port);
}

/// Utility for discovering thermal receipt printers on the local WiFi/LAN network.
///
/// Pure Dart: does not import Flutter or dart:ui.
class NetworkDiscovery {
  const NetworkDiscovery._();

  /// Scans the local network subnet to discover ESC/POS network thermal printers.
  ///
  /// - [subnet]: Optional subnet prefix (e.g. `'192.168.1'`). If omitted, auto-detects
  ///   active IPv4 subnets from the device's local network interfaces.
  /// - [port]: The TCP port to probe (default `9100`, standard for ESC/POS network printers).
  /// - [ports]: Optional list of alternative ports to probe. Defaults to `[port]`.
  /// - [timeout]: Connection timeout per IP address (default 300 ms).
  /// - [batchSize]: Concurrency level when probing IPs (default 32 parallel probes).
  /// - [onDeviceFound]: Optional callback triggered immediately whenever a printer is discovered.
  /// - [probeHardware]: If true, queries the printer over TCP with ESC/POS hardware identification
  ///   commands (`GS I 67` / `GS I 2`) and reverse DNS to resolve model name.
  static Future<Result<List<NetworkDevice>>> discoverPrinters({
    String? subnet,
    int port = 9100,
    List<int>? ports,
    Duration timeout = const Duration(milliseconds: 300),
    int batchSize = 32,
    void Function(NetworkDevice device)? onDeviceFound,
    bool probeHardware = true,
  }) async {
    final subnetsToScan = <String>[];

    if (subnet != null && subnet.trim().isNotEmpty) {
      subnetsToScan.add(subnet.trim());
    } else {
      final detected = await findLocalSubnets();
      subnetsToScan.addAll(detected);
    }

    if (subnetsToScan.isEmpty) {
      PosLogger.warning(
          'NetworkDiscovery: No active local IPv4 network interface found.');
      return const Result.error(
        PrinterError(
          PrinterErrorCode.connectionFailed,
          message: 'No active local network connection found.',
          hint:
              'Make sure your device is connected to a WiFi or Ethernet network.',
        ),
      );
    }

    final targetPorts = ports ?? [port];
    final discovered = <NetworkDevice>[];

    for (final sub in subnetsToScan) {
      PosLogger.info(
          'NetworkDiscovery: Scanning subnet $sub on port(s) ${targetPorts.join(',')}...');

      for (final targetPort in targetPorts) {
        // Probe IPs 1..254 in concurrent batches
        for (var i = 1; i <= 254; i += batchSize) {
          final end = (i + batchSize - 1).clamp(1, 254);
          final batchFutures = <Future<void>>[];

          for (var hostNum = i; hostNum <= end; hostNum++) {
            final ip = '$sub.$hostNum';
            batchFutures.add(
              probeHost(
                ip,
                port: targetPort,
                timeout: timeout,
                probeHardware: probeHardware,
              ).then((device) {
                if (device != null) {
                  discovered.add(device);
                  onDeviceFound?.call(device);
                }
              }),
            );
          }

          await Future.wait(batchFutures);
        }
      }
    }

    PosLogger.info(
        'NetworkDiscovery: Finished scan. Found ${discovered.length} printer(s).');
    return Result.ok(discovered);
  }

  /// Probes a single host and port to determine if an ESC/POS printer is listening,
  /// resolving its device name and model.
  static Future<NetworkDevice?> probeHost(
    String ip, {
    int port = 9100,
    Duration timeout = const Duration(milliseconds: 300),
    bool probeHardware = true,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: timeout);
    } catch (_) {
      // Host unreachable or port not listening
      return null;
    }

    String? hostName;
    String? model;

    try {
      // 1. Reverse DNS resolution
      try {
        final reverse = await InternetAddress(ip).reverse();
        if (reverse.host != ip && reverse.host.trim().isNotEmpty) {
          hostName = reverse.host.trim();
        }
      } catch (_) {}

      // 2. Hardware probe via ESC/POS GS I query
      if (probeHardware) {
        model = await _queryPrinterModel(socket, timeout);
      }
    } catch (e) {
      PosLogger.debug('Probe metadata error for $ip: $e');
    } finally {
      try {
        socket.destroy();
      } catch (_) {}
    }

    final cleanModel = model ??
        _extractModelFromHostName(hostName) ??
        'ESC/POS Network Printer';
    final cleanName = hostName ?? '$cleanModel ($ip)';

    return NetworkDevice(
      ip: ip,
      port: port,
      name: cleanName,
      model: cleanModel,
      hostName: hostName,
    );
  }

  /// Returns active local IPv4 subnet prefixes (e.g. `['192.168.1']`).
  static Future<List<String>> findLocalSubnets() async {
    final subnets = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            final parts = address.address.split('.');
            if (parts.length == 4) {
              subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }
    } catch (e) {
      PosLogger.error('Failed to list network interfaces: $e');
    }
    return subnets.toList();
  }

  /// Sends standard ESC/POS printer hardware ID inquiry commands (`GS I 67` and `GS I 2`)
  /// to query the printer name and model.
  static Future<String?> _queryPrinterModel(
      Socket socket, Duration timeout) async {
    final completer = Completer<String?>();
    StreamSubscription<Uint8List>? sub;
    Timer? timer;

    final responseBuffer = <int>[];

    void finish([String? result]) {
      timer?.cancel();
      sub?.cancel();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    // Safety timeout in case printer does not reply to GS I inquiry
    timer = Timer(const Duration(milliseconds: 250), () {
      if (responseBuffer.isNotEmpty) {
        finish(_parseModelBytes(responseBuffer));
      } else {
        finish(null);
      }
    });

    sub = socket.listen(
      (data) {
        responseBuffer.addAll(data);
        if (data.contains(0x00) ||
            data.contains(0x0A) ||
            responseBuffer.length >= 16) {
          finish(_parseModelBytes(responseBuffer));
        }
      },
      onError: (_) => finish(null),
      onDone: () {
        if (responseBuffer.isNotEmpty) {
          finish(_parseModelBytes(responseBuffer));
        } else {
          finish(null);
        }
      },
      cancelOnError: true,
    );

    try {
      // GS I 67 (0x1D 0x49 0x43) - Transmit printer name
      // GS I 2  (0x1D 0x49 0x02) - Transmit printer type/model ID
      socket.add(const [0x1D, 0x49, 0x43, 0x1D, 0x49, 0x02]);
      await socket.flush();
    } catch (_) {
      finish(null);
    }

    return completer.future;
  }

  static String? _parseModelBytes(List<int> bytes) {
    // Filter ASCII printable characters
    final chars = bytes
        .where((b) => b >= 32 && b <= 126)
        .map(String.fromCharCode)
        .join()
        .trim();
    if (chars.length >= 2) {
      return chars;
    }
    return null;
  }

  static String? _extractModelFromHostName(String? hostName) {
    if (hostName == null || hostName.isEmpty) return null;
    var clean = hostName.split('.').first;
    clean = clean.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (clean.isNotEmpty) {
      return clean;
    }
    return null;
  }
}
