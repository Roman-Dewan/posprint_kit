import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
// OLD: import 'package:flutter/rendering.dart';

import '../core/ops.dart';
import '../core/raster.dart';
import '../core/text_rasterizer.dart';

/// Flutter text-engine implementation of [TextRasterizer].
///
/// Uses `dart:ui` paragraph shaping, locale support, and glyph fallback
/// to render complex scripts (Bangla, Chinese, Japanese, Korean, Arabic, Hindi, Thai)
/// with exact shaping, conjunct clusters, and alignment.
class FlutterTextRasterizer implements TextRasterizer {
  FlutterTextRasterizer({this.enableCache = true});

  final bool enableCache;
  final Map<String, GrayBitmap> _cache = {};

  @override
  Future<GrayBitmap> renderText(
    String text, {
    required int widthDots,
    required TextStyleSpec style,
    PosAlign align = PosAlign.left,
    String? languageTag,
  }) async {
    final cacheKey =
        '$text|$widthDots|${style.fontSize}|${style.bold}|${style.fontFamily}|$align|$languageTag';
    if (enableCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final isRtl = _isRtl(languageTag);
    final textAlign = _toTextAlign(align, isRtl);
    final textDirection = isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr;

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: textAlign,
      textDirection: textDirection,
      fontSize: style.fontSize,
      fontWeight: style.bold ? ui.FontWeight.bold : ui.FontWeight.normal,
      fontFamily: style.fontFamily,
      locale: languageTag != null ? ui.Locale(languageTag) : null,
      height: style.lineHeight,
    );

    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(
        ui.TextStyle(
          color: const ui.Color(0xFF000000), // black text on white
          fontSize: style.fontSize,
          fontWeight: style.bold ? ui.FontWeight.bold : ui.FontWeight.normal,
          fontFamily: style.fontFamily,
          fontFamilyFallback: style.fontFamilyFallback ??
              const [
                'Noto Sans',
                'Noto Sans Bengali',
                'Noto Sans CJK SC',
                'Noto Sans CJK JP',
                'Noto Sans Devanagari',
                'Noto Sans Arabic',
                'Noto Sans Thai',
              ],
          letterSpacing: style.letterSpacing,
        ),
      )
      ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: widthDots.toDouble()));

    final height = (paragraph.height.ceil()).clamp(1, 10000);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Fill white background
    final bgPaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, widthDots.toDouble(), height.toDouble()),
      bgPaint,
    );

    // Draw shaped text
    canvas.drawParagraph(paragraph, ui.Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(widthDots, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      throw StateError('Failed to extract RGBA bytes from rendered paragraph');
    }

    final gray = _rgbaToGrayscale(
      byteData: byteData,
      width: widthDots,
      height: height,
    );

    if (enableCache) {
      _cache[cacheKey] = gray;
    }

    return gray;
  }

  @override
  Future<GrayBitmap> renderRow(
    String left,
    String right, {
    required int widthDots,
    required TextStyleSpec style,
    String? languageTag,
  }) async {
    final cacheKey =
        'ROW:$left|$right|$widthDots|${style.fontSize}|${style.bold}|$languageTag';
    if (enableCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final locale = languageTag != null ? ui.Locale(languageTag) : null;
    final fallback = style.fontFamilyFallback ??
        const [
          'Noto Sans',
          'Noto Sans Bengali',
          'Noto Sans CJK SC',
          'Noto Sans CJK JP',
          'Noto Sans Devanagari',
          'Noto Sans Arabic',
          'Noto Sans Thai',
        ];

    final textStyle = ui.TextStyle(
      color: const ui.Color(0xFF000000),
      fontSize: style.fontSize,
      fontWeight: style.bold ? ui.FontWeight.bold : ui.FontWeight.normal,
      fontFamily: style.fontFamily,
      fontFamilyFallback: fallback,
      letterSpacing: style.letterSpacing,
    );

    // 1. Measure right text (e.g. price/amount)
    final rightStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.right,
      textDirection: ui.TextDirection.ltr,
      fontSize: style.fontSize,
      fontWeight: style.bold ? ui.FontWeight.bold : ui.FontWeight.normal,
      locale: locale,
      height: style.lineHeight,
    );
    final rightBuilder = ui.ParagraphBuilder(rightStyle)
      ..pushStyle(textStyle)
      ..addText(right);
    final rightParagraph = rightBuilder.build()
      ..layout(ui.ParagraphConstraints(width: widthDots.toDouble()));

    final rightWidth = (rightParagraph.maxIntrinsicWidth.ceil()).toDouble();
    const gap = 16.0; // minimum space between left and right columns
    final leftWidthAvailable = (widthDots - rightWidth - gap).clamp(20.0, widthDots.toDouble());

    // 2. Measure and wrap left text inside remaining box
    final isLeftRtl = _isRtl(languageTag);
    final leftStyle = ui.ParagraphStyle(
      textAlign: isLeftRtl ? ui.TextAlign.right : ui.TextAlign.left,
      textDirection: isLeftRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      fontSize: style.fontSize,
      fontWeight: style.bold ? ui.FontWeight.bold : ui.FontWeight.normal,
      locale: locale,
      height: style.lineHeight,
    );
    final leftBuilder = ui.ParagraphBuilder(leftStyle)
      ..pushStyle(textStyle)
      ..addText(left);
    final leftParagraph = leftBuilder.build()
      ..layout(ui.ParagraphConstraints(width: leftWidthAvailable));

    final rowHeight = (leftParagraph.height > rightParagraph.height
            ? leftParagraph.height.ceil()
            : rightParagraph.height.ceil())
        .clamp(1, 10000);

    // 3. Draw both onto canvas
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final bgPaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, widthDots.toDouble(), rowHeight.toDouble()),
      bgPaint,
    );

    canvas.drawParagraph(leftParagraph, ui.Offset.zero);

    // OLD:
    // final rightX = widthDots.toDouble() - rightWidth;
    // canvas.drawParagraph(rightParagraph, ui.Offset(rightX, 0));
    // Since rightParagraph was laid out with width: widthDots and textAlign: right,
    // drawing at Offset.zero renders it flush against the right margin (widthDots).
    canvas.drawParagraph(rightParagraph, ui.Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(widthDots, rowHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      throw StateError('Failed to extract RGBA bytes from rendered row');
    }

    final gray = _rgbaToGrayscale(
      byteData: byteData,
      width: widthDots,
      height: rowHeight,
    );

    if (enableCache) {
      _cache[cacheKey] = gray;
    }

    return gray;
  }

  /// Converts RGBA byte data to 8-bit luminance values (0=black, 255=white).
  static GrayBitmap _rgbaToGrayscale({
    required ByteData byteData,
    required int width,
    required int height,
  }) {
    final pixels = Uint8List(width * height);
    final bytes = byteData.buffer.asUint8List();

    for (var i = 0, p = 0; i < bytes.length; i += 4, p++) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final a = bytes[i + 3];

      if (a < 128) {
        pixels[p] = 255; // transparent pixel becomes white background
      } else {
        // Standard Rec. 601 luma conversion
        pixels[p] = ((299 * r + 587 * g + 114 * b) ~/ 1000).clamp(0, 255);
      }
    }

    return GrayBitmap(width: width, height: height, pixels: pixels);
  }

  static bool _isRtl(String? languageTag) {
    if (languageTag == null) return false;
    final tag = languageTag.toLowerCase();
    return tag.startsWith('ar') ||
        tag.startsWith('he') ||
        tag.startsWith('fa') ||
        tag.startsWith('ur');
  }

  static ui.TextAlign _toTextAlign(PosAlign align, bool isRtl) {
    switch (align) {
      case PosAlign.left:
        return isRtl ? ui.TextAlign.right : ui.TextAlign.left;
      case PosAlign.center:
        return ui.TextAlign.center;
      case PosAlign.right:
        return isRtl ? ui.TextAlign.left : ui.TextAlign.right;
    }
  }

  /// Clears the rendered line cache.
  void clearCache() => _cache.clear();
}
