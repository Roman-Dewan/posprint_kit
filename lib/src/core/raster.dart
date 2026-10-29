import 'dart:typed_data';

import 'commands.dart';

/// An 8-bit grayscale bitmap where each pixel is represented by a byte (0=black, 255=white).
class GrayBitmap {
  GrayBitmap({
    required this.width,
    required this.height,
    required this.pixels,
  }) : assert(pixels.length == width * height, 'pixels length must equal width * height');

  /// Creates a blank white grayscale bitmap of the given dimensions.
  factory GrayBitmap.blank(int width, int height) {
    final pixels = Uint8List(width * height);
    pixels.fillRange(0, pixels.length, 255);
    return GrayBitmap(width: width, height: height, pixels: pixels);
  }

  /// Width in pixels/dots.
  final int width;

  /// Height in pixels/dots.
  final int height;

  /// Raw 8-bit grayscale pixels (row-major).
  final Uint8List pixels;

  /// Converts this grayscale image into a 1-bit monochrome bitmap ([MonoBitmap])
  /// packed 8 pixels per byte, MSB first (0 = white/no heat, 1 = black/heat).
  ///
  /// [threshold]: luminance cutoff between 0 and 255 (default 128). Pixels darker
  /// than this threshold are burned black.
  /// [dither]: whether to apply Floyd-Steinberg error diffusion dithering instead
  /// of strict thresholding.
  MonoBitmap toMono({int threshold = 128, bool dither = false}) {
    final bytesPerLine = (width + 7) ~/ 8;
    final monoData = Uint8List(bytesPerLine * height);

    if (dither) {
      return _toMonoDithered(threshold);
    }

    for (var y = 0; y < height; y++) {
      final lineOffset = y * bytesPerLine;
      final rowOffset = y * width;
      for (var x = 0; x < width; x++) {
        final pixel = pixels[rowOffset + x];
        if (pixel < threshold) {
          final byteIndex = lineOffset + (x >> 3);
          final bitIndex = 7 - (x & 7);
          monoData[byteIndex] |= (1 << bitIndex);
        }
      }
    }

    return MonoBitmap(
      width: width,
      height: height,
      bytesPerLine: bytesPerLine,
      data: monoData,
    );
  }

  MonoBitmap _toMonoDithered(int threshold) {
    final bytesPerLine = (width + 7) ~/ 8;
    final monoData = Uint8List(bytesPerLine * height);

    // Working copy with float buffer for error diffusion
    final buffer = Float32List.fromList(pixels.map((p) => p.toDouble()).toList());

    for (var y = 0; y < height; y++) {
      final lineOffset = y * bytesPerLine;
      final rowOffset = y * width;

      for (var x = 0; x < width; x++) {
        final idx = rowOffset + x;
        final oldVal = buffer[idx];
        final newVal = oldVal < threshold ? 0.0 : 255.0;
        final err = oldVal - newVal;

        if (newVal == 0.0) {
          final byteIndex = lineOffset + (x >> 3);
          final bitIndex = 7 - (x & 7);
          monoData[byteIndex] |= (1 << bitIndex);
        }

        // Distribute error to neighbors (Floyd-Steinberg)
        if (x + 1 < width) {
          buffer[idx + 1] += err * (7.0 / 16.0);
        }
        if (y + 1 < height) {
          final nextRow = idx + width;
          if (x > 0) {
            buffer[nextRow - 1] += err * (3.0 / 16.0);
          }
          buffer[nextRow] += err * (5.0 / 16.0);
          if (x + 1 < width) {
            buffer[nextRow + 1] += err * (1.0 / 16.0);
          }
        }
      }
    }

    return MonoBitmap(
      width: width,
      height: height,
      bytesPerLine: bytesPerLine,
      data: monoData,
    );
  }
}

/// A 1-bit monochrome bitmap packed 8 pixels per byte, ready for ESC/POS `GS v 0` printing.
class MonoBitmap {
  MonoBitmap({
    required this.width,
    required this.height,
    required this.bytesPerLine,
    required this.data,
  }) : assert(
          data.length == bytesPerLine * height,
          'data length must equal bytesPerLine * height',
        );

  /// Width in dots.
  final int width;

  /// Height in dots.
  final int height;

  /// Number of bytes in each row of dots (`(width + 7) ~/ 8`).
  final int bytesPerLine;

  /// 1-bit packed data (1 = black/heat, 0 = white/no heat).
  final Uint8List data;

  /// Splits this bitmap into horizontal bands no taller than [maxBandRows]
  /// to prevent overflowing small printer buffers.
  List<MonoBitmap> toBands(int maxBandRows) {
    if (height <= maxBandRows) {
      return [this];
    }

    final bands = <MonoBitmap>[];
    var currentY = 0;

    while (currentY < height) {
      final bandHeight = (height - currentY).clamp(1, maxBandRows);
      final startByte = currentY * bytesPerLine;
      final endByte = (currentY + bandHeight) * bytesPerLine;
      final bandData = data.sublist(startByte, endByte);

      bands.add(
        MonoBitmap(
          width: width,
          height: bandHeight,
          bytesPerLine: bytesPerLine,
          data: bandData,
        ),
      );

      currentY += bandHeight;
    }

    return bands;
  }

  /// Encodes this bitmap into an ESC/POS `GS v 0` command sequence.
  Uint8List toEscPosBytes() {
    final header = Commands.rasterHeader(
      bytesPerLine: bytesPerLine,
      heightDots: height,
    );
    final result = Uint8List(header.length + data.length);
    result.setRange(0, header.length, header);
    result.setRange(header.length, result.length, data);
    return result;
  }
}

