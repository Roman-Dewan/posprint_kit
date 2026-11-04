import '../core/raster.dart';
import 'tspl_enums.dart';
import 'tspl_ops.dart';
import 'tspl_size.dart';

/// A fluent builder for creating coordinate-based sticker labels and barcodes
/// using TSPL (TSC Printer Language).
///
/// Example:
/// ```dart
/// final label = TsplLabel(size: TsplSize.size40x30)
///   ..direction(TsplDirection.normal)
///   ..box(x: 5, y: 5, endX: 315, endY: 235, thickness: 2)
///   ..text('ORGANIC HONEY', x: 20, y: 20, font: TsplFont.font3)
///   ..textRaster('খাঁটি মধু ৫০০ গ্রাম', x: 20, y: 55, fontSize: 18, languageTag: 'bn')
///   ..barcode('890123456789', x: 20, y: 95, height: 45)
///   ..qr('https://honey.example.com', x: 220, y: 95, size: 4)
///   ..text('PRICE: \$12.50', x: 20, y: 165, font: TsplFont.font4)
///   ..print(copies: 1);
/// ```
class TsplLabel {
  /// Creates a new label layout with target [size] (defaults to `40 × 30 mm`).
  TsplLabel({
    this.size = TsplSize.size40x30,
    this.direction = TsplDirection.normal,
    this.referenceX = 0,
    this.referenceY = 0,
    this.speed,
    this.density,
    this.copies = 1,
    this.autoCut = false,
  });

  /// Physical dimensions and DPI of the sticker media.
  TsplSize size;

  /// Printing direction (normal top-to-bottom or 180° reverse).
  TsplDirection direction;

  /// Custom gap distance override in millimeters (null uses [size.gapMm]).
  double? customGapMm;

  /// Origin reference X offset in dots.
  int referenceX;

  /// Origin reference Y offset in dots.
  int referenceY;

  /// Print speed in inches/sec (2 to 6, optional).
  int? speed;

  /// Darkness/density setting (0 to 15, optional).
  int? density;

  /// Number of copies to print when executed.
  int copies;

  /// Whether to issue a paper cut command at the end of printing.
  bool autoCut;

  /// The list of visual elements placed on the label.
  final List<TsplOp> ops = [];

  // ---------------------------------------------------------------------------
  // FLUENT CONFIGURATION
  // ---------------------------------------------------------------------------

  /// Sets the physical label size.
  TsplLabel setSize(TsplSize newSize) {
    size = newSize;
    return this;
  }

  /// Sets the feed direction.
  TsplLabel setDirection(TsplDirection newDirection) {
    direction = newDirection;
    return this;
  }

  /// Sets label gap distance and offset in millimeters.
  TsplLabel gap(double gapMm) {
    customGapMm = gapMm;
    return this;
  }

  /// Sets the coordinate origin offset in dots.
  TsplLabel reference(int x, int y) {
    referenceX = x;
    referenceY = y;
    return this;
  }

  /// Sets print speed in inches per second (typically 2 to 6).
  TsplLabel setSpeed(int inchesPerSecond) {
    speed = inchesPerSecond;
    return this;
  }

  /// Sets print darkness/density (typically 0 to 15).
  TsplLabel setDensity(int darkness) {
    density = darkness;
    return this;
  }

  // ---------------------------------------------------------------------------
  // VISUAL ELEMENT BUILDERS
  // ---------------------------------------------------------------------------

  /// Adds a text element using built-in printer ROM fonts.
  ///
  /// For Latin text and digits, ROM fonts are crisp and fast. For complex
  /// multilingual scripts (Bangla, Arabic, Hindi, CJK), use [textRaster].
  TsplLabel text(
    String text, {
    required int x,
    required int y,
    TsplFont font = TsplFont.font3,
    TsplRotation rotation = TsplRotation.deg0,
    int xMultiplication = 1,
    int yMultiplication = 1,
  }) {
    ops.add(TsplTextOp(
      text: text,
      x: x,
      y: y,
      font: font,
      rotation: rotation,
      xMultiplication: xMultiplication,
      yMultiplication: yMultiplication,
    ));
    return this;
  }

  /// Adds a 1D linear barcode element.
  TsplLabel barcode(
    String data, {
    required int x,
    required int y,
    TsplBarcodeType type = TsplBarcodeType.code128,
    required int height,
    TsplHumanReadable humanReadable = TsplHumanReadable.belowCenter,
    TsplRotation rotation = TsplRotation.deg0,
    int narrow = 2,
    int wide = 2,
  }) {
    ops.add(TsplBarcodeOp(
      data: data,
      x: x,
      y: y,
      type: type,
      height: height,
      humanReadable: humanReadable,
      rotation: rotation,
      narrow: narrow,
      wide: wide,
    ));
    return this;
  }

  /// Adds a 2D QR Code element.
  ///
  /// [size] specifies module cell width in dots (1 to 16, default 4).
  TsplLabel qr(
    String data, {
    required int x,
    required int y,
    int size = 4,
    TsplQrEcc ecc = TsplQrEcc.medium,
    TsplRotation rotation = TsplRotation.deg0,
  }) {
    ops.add(TsplQrOp(
      data: data,
      x: x,
      y: y,
      size: size,
      ecc: ecc,
      rotation: rotation,
    ));
    return this;
  }

  /// Draws a rectangular border box.
  TsplLabel box({
    required int x,
    required int y,
    required int endX,
    required int endY,
    int thickness = 2,
    int? radius,
  }) {
    ops.add(TsplBoxOp(
      x: x,
      y: y,
      endX: endX,
      endY: endY,
      thickness: thickness,
      radius: radius,
    ));
    return this;
  }

  /// Draws a solid horizontal or vertical bar.
  TsplLabel bar({
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    ops.add(TsplBarOp(
      x: x,
      y: y,
      width: width,
      height: height,
    ));
    return this;
  }

  /// Helper to draw a horizontal dividing line across the label.
  TsplLabel line({
    required int x,
    required int y,
    required int width,
    int thickness = 2,
  }) {
    return bar(x: x, y: y, width: width, height: thickness);
  }

  /// Inverts colors (white on black) in the specified rectangular region.
  TsplLabel reverse({
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    ops.add(TsplReverseOp(
      x: x,
      y: y,
      width: width,
      height: height,
    ));
    return this;
  }

  /// Draws a 1-bit monochrome bitmap onto the label.
  TsplLabel image(
    MonoBitmap bitmap, {
    required int x,
    required int y,
    TsplBitmapMode mode = TsplBitmapMode.overwrite,
  }) {
    ops.add(TsplBitmapOp(
      bitmap: bitmap,
      x: x,
      y: y,
      mode: mode,
    ));
    return this;
  }

  /// Renders complex multilingual text (Bangla, Arabic, Hindi, CJK, etc.)
  /// into a 1-bit raster graphic and draws it using TSPL `BITMAP`.
  ///
  /// Guarantees that non-Latin scripts print accurately on standard label printers
  /// without requiring special Chinese/Unicode firmware fonts.
  TsplLabel textRaster(
    String text, {
    required int x,
    required int y,
    double fontSize = 20.0,
    bool bold = false,
    String? fontFamily,
    String? languageTag,
    int? maxWidth,
  }) {
    ops.add(TsplRasterTextOp(
      text: text,
      x: x,
      y: y,
      fontSize: fontSize,
      bold: bold,
      fontFamily: fontFamily,
      languageTag: languageTag,
      maxWidth: maxWidth,
    ));
    return this;
  }

  /// Appends a cut command at the end of this print job.
  TsplLabel cut() {
    autoCut = true;
    return this;
  }

  /// Sets the number of copies to print.
  TsplLabel print({int copies = 1}) {
    this.copies = copies;
    return this;
  }
}
