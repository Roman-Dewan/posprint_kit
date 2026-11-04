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
    required this.x,
    required this.y,
    this.font = TsplFont.font3,
    this.rotation = TsplRotation.deg0,
    this.xMultiplication = 1,
    this.yMultiplication = 1,
  })  : assert(xMultiplication >= 1 && xMultiplication <= 10,
            'xMultiplication must be between 1 and 10'),
        assert(yMultiplication >= 1 && yMultiplication <= 10,
            'yMultiplication must be between 1 and 10');

  final String text;
  final int x;
  final int y;
  final TsplFont font;
  final TsplRotation rotation;
  final int xMultiplication;
  final int yMultiplication;
}

/// 1D linear barcode element.
class TsplBarcodeOp extends TsplOp {
  const TsplBarcodeOp({
    required this.data,
    required this.x,
    required this.y,
    this.type = TsplBarcodeType.code128,
    required this.height,
    this.humanReadable = TsplHumanReadable.belowCenter,
    this.rotation = TsplRotation.deg0,
    this.narrow = 2,
    this.wide = 2,
  }) : assert(height > 0, 'Barcode height must be positive.');

  final String data;
  final int x;
  final int y;
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
    required this.x,
    required this.y,
    this.size = 4,
    this.ecc = TsplQrEcc.medium,
    this.rotation = TsplRotation.deg0,
  }) : assert(size >= 1 && size <= 16, 'QR module cell size must be between 1 and 16 dots.');

  final String data;
  final int x;
  final int y;
  final int size;
  final TsplQrEcc ecc;
  final TsplRotation rotation;
}

/// Rectangle outline border with optional corner rounding radius.
class TsplBoxOp extends TsplOp {
  const TsplBoxOp({
    required this.x,
    required this.y,
    required this.endX,
    required this.endY,
    this.thickness = 2,
    this.radius,
  })  : assert(endX >= x, 'endX must be >= x'),
        assert(endY >= y, 'endY must be >= y'),
        assert(thickness > 0, 'thickness must be positive.');

  final int x;
  final int y;
  final int endX;
  final int endY;
  final int thickness;
  final int? radius;
}

/// Solid bar / line element.
class TsplBarOp extends TsplOp {
  const TsplBarOp({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  })  : assert(width > 0, 'width must be positive'),
        assert(height > 0, 'height must be positive');

  final int x;
  final int y;
  final int width;
  final int height;
}

/// White on black color inversion rectangle.
class TsplReverseOp extends TsplOp {
  const TsplReverseOp({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  })  : assert(width > 0, 'width must be positive'),
        assert(height > 0, 'height must be positive');

  final int x;
  final int y;
  final int width;
  final int height;
}

/// Direct 1-bit monochrome bitmap drawing.
class TsplBitmapOp extends TsplOp {
  const TsplBitmapOp({
    required this.bitmap,
    required this.x,
    required this.y,
    this.mode = TsplBitmapMode.overwrite,
  });

  final MonoBitmap bitmap;
  final int x;
  final int y;
  final TsplBitmapMode mode;
}

/// Multilingual text rendered via Flutter text engine into 1-bit raster graphic.
///
/// Guaranteed support for non-Latin scripts (Bangla, Arabic, Hindi, Japanese,
/// Korean, etc.) on any standard TSPL printer without custom firmware ROM fonts.
class TsplRasterTextOp extends TsplOp {
  const TsplRasterTextOp({
    required this.text,
    required this.x,
    required this.y,
    this.fontSize = 20.0,
    this.bold = false,
    this.fontFamily,
    this.languageTag,
    this.maxWidth,
  }) : assert(fontSize > 0, 'fontSize must be positive.');

  final String text;
  final int x;
  final int y;
  final double fontSize;
  final bool bold;
  final String? fontFamily;
  final String? languageTag;
  final int? maxWidth;
}
