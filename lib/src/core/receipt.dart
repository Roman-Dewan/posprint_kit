import 'dart:typed_data';

import 'ops.dart';
import 'raster.dart';
import 'text_rasterizer.dart';

/// A printable receipt representation.
///
/// Records a sequence of receipt operations ([ReceiptOp]) using a fluent builder API.
/// Independent of printer hardware details, paper size, and transport medium.
///
/// Example:
/// ```dart
/// final receipt = Receipt()
///   ..title('MY RESTAURANT')
///   ..row('Burger x2', '12.00')
///   ..row('বার্গার x1', '6.00')
///   ..divider()
///   ..total('TOTAL', '18.00')
///   ..cut();
/// ```
class Receipt {
  Receipt([List<ReceiptOp>? initialOps]) : ops = initialOps != null ? List.of(initialOps) : [];

  /// Ready-made template for a standard retail/restaurant receipt.
  ///
  /// ```dart
  /// final receipt = Receipt.simple(
  ///   title: 'CAFE LATTE',
  ///   items: [('Espresso', '3.50'), ('Croissant', '4.00')],
  ///   total: '7.50',
  /// );
  /// ```
  factory Receipt.simple({
    required String title,
    required List<(String, String)> items,
    required String total,
    String? footer,
  }) {
    final receipt = Receipt()
      ..title(title)
      ..divider();

    for (final (name, price) in items) {
      receipt.row(name, price);
    }

    receipt
      ..divider()
      ..total('TOTAL', total);

    if (footer != null && footer.isNotEmpty) {
      receipt
        ..feed(1)
        ..text(footer, align: PosAlign.center);
    }

    return receipt..feed(2)..cut();
  }

  /// The recorded list of printing operations.
  final List<ReceiptOp> ops;

  Receipt _add(ReceiptOp op) {
    ops.add(op);
    return this;
  }

  /// Prints a line of text [s].
  ///
  /// Defaults to [PosAlign.left], normal weight and size, and [TextMode.auto].
  Receipt text(
    String s, {
    PosAlign align = PosAlign.left,
    bool bold = false,
    TextSize size = TextSize.normal,
    TextMode mode = TextMode.auto,
    String? languageTag,
    TextStyleSpec style = const TextStyleSpec(),
  }) =>
      _add(
        TextOp(
          s,
          align: align,
          bold: bold,
          size: size,
          mode: mode,
          languageTag: languageTag,
          style: style,
        ),
      );

  /// Prints a prominent centered title [s] in bold and double size.
  Receipt title(
    String s, {
    TextMode mode = TextMode.auto,
    String? languageTag,
  }) =>
      _add(
        TextOp(
          s,
          align: PosAlign.center,
          bold: true,
          size: TextSize.doubleSize,
          mode: mode,
          languageTag: languageTag,
          style: const TextStyleSpec(fontSize: 32, bold: true),
        ),
      );

  /// Prints a two-column row with [left] item description and [right] price/amount
  /// flush against the right margin.
  ///
  /// In [TextMode.auto], if the row contains non-Latin scripts (e.g. Bangla, Arabic,
  /// Chinese), the entire row is laid out in pixels and printed as an image so that
  /// script shaping and right-alignment are pixel-perfect.
  Receipt row(
    String left,
    String right, {
    bool bold = false,
    TextMode mode = TextMode.auto,
    String? languageTag,
    TextStyleSpec style = const TextStyleSpec(),
  }) =>
      _add(
        RowOp(
          left,
          right,
          bold: bold,
          mode: mode,
          languageTag: languageTag,
          style: style,
        ),
      );

  /// Prints a horizontal divider line across the full paper width.
  Receipt divider({String character = '-'}) =>
      _add(DividerOp(character: character));

  /// Prints a bold total summary row with [label] and [amount].
  Receipt total(
    String label,
    String amount, {
    TextMode mode = TextMode.auto,
    String? languageTag,
  }) =>
      _add(
        RowOp(
          label,
          amount,
          bold: true,
          mode: mode,
          languageTag: languageTag,
          style: const TextStyleSpec(fontSize: 28, bold: true),
        ),
      );

  /// Prints a QR code containing [data].
  ///
  /// [size]: module size in dots (1 to 16, default 6).
  /// [errorCorrection]: error recovery level ([QrErrorCorrectionLevel.m] by default).
  Receipt qr(
    String data, {
    int size = 6,
    QrErrorCorrectionLevel errorCorrection = QrErrorCorrectionLevel.m,
  }) =>
      _add(QrOp(data, size: size, errorCorrection: errorCorrection));

  /// Prints a 1D barcode with [data].
  ///
  /// Supported types: [BarcodeType.code128] and [BarcodeType.ean13].
  Receipt barcode(
    String data, {
    BarcodeType type = BarcodeType.code128,
    int height = 64,
    int width = 2,
    int hri = 2,
  }) =>
      _add(
        BarcodeOp(
          data,
          type: type,
          height: height,
          width: width,
          hri: hri,
        ),
      );

  /// Prints a pre-rendered monochrome bitmap [bitmap].
  Receipt image(MonoBitmap bitmap) => _add(ImageOp(bitmap));

  /// Feeds the paper forward by [lines].
  Receipt feed([int lines = 1]) => _add(FeedOp(lines));

  /// Cuts the receipt paper.
  ///
  /// [partial]: if `true` and supported by printer profile, leaves a single point
  /// uncut so the paper does not drop to the floor.
  Receipt cut({bool partial = false, int feedDots = 3}) =>
      _add(CutOp(partial: partial, feedDots: feedDots));

  /// Pulses the cash drawer RJ11/RJ12 port to kick open the cash drawer.
  ///
  /// [pin5]: set to `true` for cash drawers wired to pin 5 instead of pin 2.
  Receipt drawer({bool pin5 = false}) =>
      _add(CashDrawerOp(pin5: pin5));

  /// Appends raw ESC/POS byte sequence directly.
  Receipt raw(Uint8List bytes) => _add(RawBytesOp(bytes));
}

