import 'dart:typed_data';

import 'ops.dart';
import 'raster.dart';

/// Font and styling specifications for rasterizing text.
///
/// Pure Dart representation so core receipt encoding stays decoupled from `dart:ui`.
class TextStyleSpec {
  const TextStyleSpec({
    this.fontSize = 26.0,
    this.bold = false,
    this.fontFamily,
    this.fontFamilyFallback,
    this.letterSpacing,
    this.lineHeight = 1.2,
  });

  /// Approximate font size in dots/pixels.
  final double fontSize;

  /// Whether the text should be drawn with bold weight.
  final bool bold;

  /// Optional primary font family (e.g. 'Noto Sans').
  final String? fontFamily;

  /// Optional fallback font families for multilingual scripts.
  final List<String>? fontFamilyFallback;

  /// Optional character spacing in dots.
  final double? letterSpacing;

  /// Relative line height multiplier.
  final double lineHeight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextStyleSpec &&
          runtimeType == other.runtimeType &&
          fontSize == other.fontSize &&
          bold == other.bold &&
          fontFamily == other.fontFamily &&
          letterSpacing == other.letterSpacing &&
          lineHeight == other.lineHeight;

  @override
  int get hashCode => Object.hash(
        fontSize,
        bold,
        fontFamily,
        letterSpacing,
        lineHeight,
      );
}

/// Abstract interface for rendering text and rows into raster bitmaps.
///
/// In Flutter applications, this is implemented by `FlutterTextRasterizer` (using `dart:ui`).
/// In pure Dart unit tests, this is implemented by [FakeRasterizer].
abstract class TextRasterizer {
  /// Renders a single text block into a [GrayBitmap] with width [widthDots].
  Future<GrayBitmap> renderText(
    String text, {
    required int widthDots,
    required TextStyleSpec style,
    PosAlign align = PosAlign.left,
    String? languageTag,
  });

  /// Renders a two-column row on a single line, with [left] text aligned to the left
  /// and [right] text aligned flush against the right edge (dot [widthDots]).
  Future<GrayBitmap> renderRow(
    String left,
    String right, {
    required int widthDots,
    required TextStyleSpec style,
    String? languageTag,
  });
}

/// Deterministic, pure-Dart mock rasterizer for testing receipt encoding without Flutter.
class FakeRasterizer implements TextRasterizer {
  const FakeRasterizer({this.mockHeight = 24});

  /// Height in dots for mock generated bitmaps.
  final int mockHeight;

  @override
  Future<GrayBitmap> renderText(
    String text, {
    required int widthDots,
    required TextStyleSpec style,
    PosAlign align = PosAlign.left,
    String? languageTag,
  }) async {
    return _createDeterministicBitmap(widthDots, '$text|$align|${style.bold}');
  }

  @override
  Future<GrayBitmap> renderRow(
    String left,
    String right, {
    required int widthDots,
    required TextStyleSpec style,
    String? languageTag,
  }) async {
    return _createDeterministicBitmap(widthDots, '$left|$right|${style.bold}');
  }

  GrayBitmap _createDeterministicBitmap(int width, String seed) {
    final pixels = Uint8List(width * mockHeight);
    pixels.fillRange(0, pixels.length, 255); // white background

    // Draw a deterministic pattern based on hash of seed
    final hash = seed.hashCode.abs();
    final step = (hash % 7) + 2;
    for (var y = 2; y < mockHeight - 2; y++) {
      for (var x = 0; x < width; x += step) {
        pixels[y * width + x] = 0; // black dot
      }
    }

    return GrayBitmap(width: width, height: mockHeight, pixels: pixels);
  }
}

