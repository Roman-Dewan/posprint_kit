import '../core/raster.dart';
import 'tspl_enums.dart';

/// Base class for all coordinate-based visual elements on a TSPL label.
sealed class TsplOp {
  const TsplOp();
}

/// Native TSPL text command using internal printer ROM fonts.
class TsplTextOp extends TsplOp {
  const TsplTextOp({
    required this.text,
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    this.font = TsplFont.font3,
    this.rotation = TsplRotation.deg0,
    this.xMultiplication = 1,
    this.yMultiplication = 1,
  })  : horizontal = horizontal ?? x ?? 0,
        vertical = vertical ?? y ?? 0,
        assert(xMultiplication >= 1 && xMultiplication <= 10,
            'xMultiplication must be between 1 and 10'),
        assert(yMultiplication >= 1 && yMultiplication <= 10,
            'yMultiplication must be between 1 and 10');

  final String text;

  /// Horizontal position (X-axis, distance from left edge in dots).
  final int horizontal;

  /// Vertical position (Y-axis, distance from top edge in dots).
  final int vertical;

  /// Alias for [horizontal].
  int get x => horizontal;

  /// Alias for [vertical].
  int get y => vertical;

  final TsplFont font;
  final TsplRotation rotation;
  final int xMultiplication;
  final int yMultiplication;
}

/// 1D linear barcode element.
class TsplBarcodeOp extends TsplOp {
  const TsplBarcodeOp({
    required this.data,
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    this.type = TsplBarcodeType.code128,
    required this.height,
    this.humanReadable = TsplHumanReadable.belowCenter,
    this.rotation = TsplRotation.deg0,
    this.narrow = 2,
    this.wide = 2,
  })  : horizontal = horizontal ?? x ?? 0,
        vertical = vertical ?? y ?? 0,
        assert(height > 0, 'Barcode height must be positive.');

  final String data;

  /// Horizontal position (X-axis, distance from left edge in dots).
  final int horizontal;

  /// Vertical position (Y-axis, distance from top edge in dots).
  final int vertical;

  /// Alias for [horizontal].
  int get x => horizontal;

  /// Alias for [vertical].
  int get y => vertical;

  final TsplBarcodeType type;
  final int height;
  final TsplHumanReadable humanReadable;
  final TsplRotation rotation;
  final int narrow;
  final int wide;
}

/// 2D QR Code element.
class TsplQrOp extends TsplOp {
  const TsplQrOp({
    required this.data,
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    this.size = 4,
    this.ecc = TsplQrEcc.medium,
    this.rotation = TsplRotation.deg0,
  })  : horizontal = horizontal ?? x ?? 0,
        vertical = vertical ?? y ?? 0,
        assert(size >= 1 && size <= 16, 'QR module cell size must be between 1 and 16 dots.');

  final String data;

  /// Horizontal position (X-axis, distance from left edge in dots).
  final int horizontal;

  /// Vertical position (Y-axis, distance from top edge in dots).
  final int vertical;

  /// Alias for [horizontal].
  int get x => horizontal;

  /// Alias for [vertical].
  int get y => vertical;

  final int size;
  final TsplQrEcc ecc;
  final TsplRotation rotation;
}

/// Rectangle outline border with optional corner rounding radius.
class TsplBoxOp extends TsplOp {
  const TsplBoxOp({
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    int? endHorizontal,
    int? endVertical,
    int? endX,
    int? endY,
    this.thickness = 2,
    this.radius,
  })  : horizontal = horizontal ?? x ?? 0,
        vertical = vertical ?? y ?? 0,
        endHorizontal = endHorizontal ?? endX ?? (horizontal ?? x ?? 0),
        endVertical = endVertical ?? endY ?? (vertical ?? y ?? 0),
        assert((endHorizontal ?? endX ?? 0) >= (horizontal ?? x ?? 0), 'endHorizontal must be >= horizontal'),
        assert((endVertical ?? endY ?? 0) >= (vertical ?? y ?? 0), 'endVertical must be >= vertical'),
        assert(thickness > 0, 'thickness must be positive.');

  /// Upper-left horizontal position (X-axis in dots).
  final int horizontal;

  /// Upper-left vertical position (Y-axis in dots).
  final int vertical;

  /// Lower-right horizontal position (end X in dots).
  final int endHorizontal;

  /// Lower-right vertical position (end Y in dots).
  final int endVertical;

  /// Aliases for X and Y coordinates.
  int get x => horizontal;
  int get y => vertical;
  int get endX => endHorizontal;
  int get endY => endVertical;

  final int thickness;
  final int? radius;
}

/// Solid bar / line element.
class TsplBarOp extends TsplOp {
  const TsplBarOp({
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    required this.width,
    required this.height,
  })  : horizontal = horizontal ?? x ?? 0,
        vertical = vertical ?? y ?? 0,
        assert(width > 0, 'width must be positive'),
        assert(height > 0, 'height must be positive');

  /// Horizontal position (X-axis in dots).
  final int horizontal;

  /// Vertical position (Y-axis in dots).
  final int vertical;

  /// Alias for [horizontal].
  int get x => horizontal;

  /// Alias for [vertical].
  int get y => vertical;

  final int width;
  final int height;
}

/// White on black color inversion rectangle.
class TsplReverseOp extends TsplOp {
  const TsplReverseOp({
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    required this.width,
    required this.height,
  })  : horizontal = horizontal ?? x ?? 0,
        vertical = vertical ?? y ?? 0,
        assert(width > 0, 'width must be positive'),
        assert(height > 0, 'height must be positive');

  /// Horizontal position (X-axis in dots).
  final int horizontal;

  /// Vertical position (Y-axis in dots).
  final int vertical;

  /// Alias for [horizontal].
  int get x => horizontal;

  /// Alias for [vertical].
  int get y => vertical;

  final int width;
  final int height;
}

/// Direct 1-bit monochrome bitmap drawing.
class TsplBitmapOp extends TsplOp {
  const TsplBitmapOp({
    required this.bitmap,
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    this.mode = TsplBitmapMode.overwrite,
  })  : horizontal = horizontal ?? x ?? 0,
        vertical = vertical ?? y ?? 0;

  final MonoBitmap bitmap;

  /// Horizontal position (X-axis in dots).
  final int horizontal;

  /// Vertical position (Y-axis in dots).
  final int vertical;

  /// Alias for [horizontal].
  int get x => horizontal;

  /// Alias for [vertical].
  int get y => vertical;

  final TsplBitmapMode mode;
}

/// Multilingual text rendered via Flutter text engine into 1-bit raster graphic.
///
/// Guaranteed support for non-Latin scripts (Bangla, Arabic, Hindi, Japanese,
/// Korean, etc.) on any standard TSPL printer without custom firmware ROM fonts.
class TsplRasterTextOp extends TsplOp {
  const TsplRasterTextOp({
    required this.text,
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    this.fontSize = 20.0,
    this.bold = false,
    this.fontFamily,
    this.languageTag,
    this.maxWidth,
  })  : horizontal = horizontal ?? x ?? 0,
        vertical = vertical ?? y ?? 0,
        assert(fontSize > 0, 'fontSize must be positive.');

  final String text;

  /// Horizontal position (X-axis in dots).
  final int horizontal;

  /// Vertical position (Y-axis in dots).
  final int vertical;

  /// Alias for [horizontal].
  int get x => horizontal;

  /// Alias for [vertical].
  int get y => vertical;

  final double fontSize;
  final bool bold;
  final String? fontFamily;
  final String? languageTag;
  final int? maxWidth;
}
