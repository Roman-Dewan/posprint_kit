import 'dart:typed_data';

import 'package:qr/qr.dart';

import '../core/ops.dart';
import '../core/raster.dart';

/// Converts QR code payloads into 1-bit monochrome thermal raster bitmaps ([MonoBitmap])
/// packed 8 pixels per byte, ready for ESC/POS `GS v 0` printing.
///
/// Ensures 100% printer compatibility on WiFi, Bluetooth, and USB thermal printers
/// that do not have firmware support for Epson's proprietary `GS ( k` 2D barcode command.
class QrRasterizer {
  QrRasterizer._();

  /// Generates a [MonoBitmap] representing the QR code for [data].
  ///
  /// [widthDots]: Full width of the printer line in dots (e.g. 384 for 58 mm, 576 for 80 mm).
  /// [moduleSize]: Pixel size of each QR module/dot (clamped to prevent exceeding line width).
  /// [align]: Horizontal alignment within the printer line ([PosAlign.center] by default).
  /// [errorCorrection]: QR error correction level (L, M, Q, H). Defaults to [QrErrorCorrectionLevel.m].
  static MonoBitmap renderQr({
    required String data,
    required int widthDots,
    int moduleSize = 6,
    PosAlign align = PosAlign.center,
    QrErrorCorrectionLevel errorCorrection = QrErrorCorrectionLevel.m,
  }) {
    final qrLevel = switch (errorCorrection) {
      QrErrorCorrectionLevel.l => QrErrorCorrectLevel.L,
      QrErrorCorrectionLevel.m => QrErrorCorrectLevel.M,
      QrErrorCorrectionLevel.q => QrErrorCorrectLevel.Q,
      QrErrorCorrectionLevel.h => QrErrorCorrectLevel.H,
    };

    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: qrLevel,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;

    // Standard 4-module quiet zone around the QR code per ISO/IEC 18004
    const quietModules = 4;
    final totalModules = moduleCount + (quietModules * 2);

    // Clamp moduleSize so the entire symbol fits within the printer head width
    var mSize = moduleSize.clamp(1, 16);
    if (totalModules * mSize > widthDots) {
      mSize = (widthDots ~/ totalModules).clamp(1, 16);
    }

    final qrPixelWidth = totalModules * mSize;
    final qrPixelHeight = totalModules * mSize;

    // Calculate left offset based on alignment
    final int xOffset;
    switch (align) {
      case PosAlign.left:
        xOffset = 0;
      case PosAlign.center:
        xOffset = (widthDots - qrPixelWidth) ~/ 2;
      case PosAlign.right:
        xOffset = widthDots - qrPixelWidth;
    }

    final bytesPerLine = (widthDots + 7) ~/ 8;
    final monoData = Uint8List(bytesPerLine * qrPixelHeight);

    for (var r = 0; r < moduleCount; r++) {
      for (var c = 0; c < moduleCount; c++) {
        if (qrImage.isDark(r, c)) {
          final startY = (r + quietModules) * mSize;
          final startX = xOffset + ((c + quietModules) * mSize);

          for (var dy = 0; dy < mSize; dy++) {
            final y = startY + dy;
            if (y >= qrPixelHeight) continue;
            final lineOffset = y * bytesPerLine;

            for (var dx = 0; dx < mSize; dx++) {
              final x = startX + dx;
              if (x < 0 || x >= widthDots) continue;

              final byteIndex = lineOffset + (x >> 3);
              final bitIndex = 7 - (x & 7);
              monoData[byteIndex] |= (1 << bitIndex);
            }
          }
        }
      }
    }

    return MonoBitmap(
      width: widthDots,
      height: qrPixelHeight,
      bytesPerLine: bytesPerLine,
      data: monoData,
    );
  }
}

