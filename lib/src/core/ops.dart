import 'dart:typed_data';

import 'raster.dart';
import 'text_rasterizer.dart';

/// Text alignment within the printable line.
enum PosAlign {
  /// Aligned to the left margin.
  left,

  /// Centered across the paper width.
  center,

  /// Aligned to the right margin.
  right;

  const PosAlign();
}

/// Character size scaling for ESC/POS native printing.
enum TextSize {
  /// Standard 1x width and 1x height.
  normal,

  /// 2x width, 1x height.
  doubleWidth,

  /// 1x width, 2x height.
  doubleHeight,

  /// 2x width and 2x height.
  doubleSize;

  const TextSize();
}

/// Strategy for printing text.
enum TextMode {
  /// Automatically decides between native text and image per line.
  ///
  /// If every character in the line is supported by the printer profile's code pages,
  /// it is sent as fast native text. Otherwise, the whole line is rendered into an image
  /// using Flutter's text engine so that script conjuncts and shaping print cleanly.
  auto,

  /// Forces printing using printer native characters and code pages.
  /// Fails or throws if characters are not encodable.
  native,

  /// Always renders the text to an image before printing.
  image;

  const TextMode();
}

/// Supported 1D barcode formats.
enum BarcodeType {
  /// CODE128 barcode format.
  code128,

  /// EAN-13 European Article Number format.
  ean13;

  const BarcodeType();
}

/// QR code error correction capacity.
enum QrErrorCorrectionLevel {
  /// ~7% error correction recovery (ESC/POS code 48).
  l(0x30),

  /// ~15% error correction recovery (ESC/POS code 49, standard POS default).
  m(0x31),

  /// ~25% error correction recovery (ESC/POS code 50).
  q(0x32),

  /// ~30% error correction recovery (ESC/POS code 51).
  h(0x33);

  const QrErrorCorrectionLevel(this.byteValue);

  final int byteValue;
}

/// Sealed base class for all receipt printing operations.
sealed class ReceiptOp {
  const ReceiptOp();
}

/// Prints a line or block of text.
final class TextOp extends ReceiptOp {
  const TextOp(
    this.text, {
    this.align = PosAlign.left,
    this.bold = false,
    this.size = TextSize.normal,
    this.mode = TextMode.auto,
    this.languageTag,
    this.style = const TextStyleSpec(),
  });

  final String text;
  final PosAlign align;
  final bool bold;
  final TextSize size;
  final TextMode mode;
  final String? languageTag;
  final TextStyleSpec style;
}

/// Prints a two-column row with [left] text aligned left and [right] text flush right.
final class RowOp extends ReceiptOp {
  const RowOp(
    this.left,
    this.right, {
    this.bold = false,
    this.mode = TextMode.auto,
    this.languageTag,
    this.style = const TextStyleSpec(),
  });

  final String left;
  final String right;
  final bool bold;
  final TextMode mode;
  final String? languageTag;
  final TextStyleSpec style;
}

/// Prints a horizontal divider line across the full paper width.
final class DividerOp extends ReceiptOp {
  const DividerOp({this.character = '-'});

  final String character;
}

/// Feeds paper by [lines].
final class FeedOp extends ReceiptOp {
  const FeedOp([this.lines = 1]);

  final int lines;
}

/// Cuts the receipt paper.
final class CutOp extends ReceiptOp {
  const CutOp({this.partial = false, this.feedDots = 3});

  final bool partial;
  final int feedDots;
}

/// Prints a QR code.
final class QrOp extends ReceiptOp {
  const QrOp(
    this.data, {
    this.size = 6,
    this.errorCorrection = QrErrorCorrectionLevel.m,
  });

  final String data;
  final int size;
  final QrErrorCorrectionLevel errorCorrection;
}

/// Prints a 1D barcode.
final class BarcodeOp extends ReceiptOp {
  const BarcodeOp(
    this.data, {
    this.type = BarcodeType.code128,
    this.height = 64,
    this.width = 2,
    this.hri = 2, // 2 = text below barcode
  });

  final String data;
  final BarcodeType type;
  final int height;
  final int width;
  final int hri;
}

/// Sends a pulse to the cash drawer port.
final class CashDrawerOp extends ReceiptOp {
  const CashDrawerOp({this.pin5 = false});

  final bool pin5;
}

/// Prints a pre-rendered monochrome bitmap.
final class ImageOp extends ReceiptOp {
  const ImageOp(this.bitmap);

  final MonoBitmap bitmap;
}

/// Sends raw ESC/POS bytes directly.
final class RawBytesOp extends ReceiptOp {
  const RawBytesOp(this.bytes);

  final Uint8List bytes;
}

