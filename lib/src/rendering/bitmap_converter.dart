import 'package:flutter/foundation.dart';

import '../core/raster.dart';

class _ToMonoParams {
  const _ToMonoParams({
    required this.width,
    required this.height,
    required this.pixels,
    required this.threshold,
    required this.dither,
  });

  final int width;
  final int height;
  final Uint8List pixels;
  final int threshold;
  final bool dither;
}

MonoBitmap _isolateToMono(_ToMonoParams params) {
  final gray = GrayBitmap(
    width: params.width,
    height: params.height,
    pixels: params.pixels,
  );
  return gray.toMono(
    threshold: params.threshold,
    dither: params.dither,
  );
}

/// Converts grayscale bitmaps to 1-bit monochrome bitmaps in a background isolate
/// to keep the Flutter UI thread completely smooth during receipt printing.
class BitmapConverter {
  BitmapConverter._();

  /// Converts [gray] into a [MonoBitmap] inside a background isolate.
  static Future<MonoBitmap> toMonoAsync(
    GrayBitmap gray, {
    int threshold = 128,
    bool dither = false,
  }) {
    return compute(
      _isolateToMono,
      _ToMonoParams(
        width: gray.width,
        height: gray.height,
        pixels: gray.pixels,
        threshold: threshold,
        dither: dither,
      ),
    );
  }
}

