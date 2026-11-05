/// Printing direction orientation in TSPL.
enum TsplDirection {
  /// Standard top-to-bottom feed (TSPL: DIRECTION 0 or 1 depending on printer default).
  normal(1),

  /// 180-degree inverted feed (TSPL: DIRECTION 0).
  reverse(0);

  const TsplDirection(this.code);

  /// Hardware command parameter.
  final int code;
}

/// Rotation angle for text, barcodes, and QR codes.
enum TsplRotation {
  /// 0 degrees (no rotation).
  deg0(0),

  /// 90 degrees counterclockwise.
  deg90(90),

  /// 180 degrees counterclockwise.
  deg180(180),

  /// 270 degrees counterclockwise.
  deg270(270);

  const TsplRotation(this.degrees);

  /// Rotation in degrees.
  final int degrees;
}

/// Standard built-in ROM fonts available on TSPL compatible printers.
enum TsplFont {
  /// 8 × 12 dots alphanumeric font.
  font1('1'),

  /// 12 × 20 dots alphanumeric font.
  font2('2'),

  /// 16 × 24 dots alphanumeric font (standard item text).
  font3('3'),

  /// 24 × 32 dots alphanumeric font (prominent text / titles).
  font4('4'),

  /// 32 × 48 dots alphanumeric font (large numbers / totals).
  font5('5'),

  /// Simplified Chinese 24 × 24 dots font (TSS24.BF2).
  simplifiedChinese24('TSS24.BF2'),

  /// Traditional Chinese 24 × 24 dots font (TST24.BF2).
  traditionalChinese24('TST24.BF2'),

  /// Korean 24 × 24 dots font (K).
  korean24('K');

  const TsplFont(this.commandName);

  /// The font identifier string sent in the TSPL TEXT command.
  final String commandName;

  /// Font character height in printer dots at standard 203 DPI (8 dots/mm).
  int get heightDots {
    switch (this) {
      case TsplFont.font1:
        return 12;
      case TsplFont.font2:
        return 20;
      case TsplFont.font3:
        return 24;
      case TsplFont.font4:
        return 32;
      case TsplFont.font5:
        return 48;
      case TsplFont.simplifiedChinese24:
      case TsplFont.traditionalChinese24:
      case TsplFont.korean24:
        return 24;
    }
  }

  /// Font character width in printer dots at standard 203 DPI (8 dots/mm).
  int get widthDots {
    switch (this) {
      case TsplFont.font1:
        return 8;
      case TsplFont.font2:
        return 12;
      case TsplFont.font3:
        return 16;
      case TsplFont.font4:
        return 24;
      case TsplFont.font5:
        return 32;
      case TsplFont.simplifiedChinese24:
      case TsplFont.traditionalChinese24:
      case TsplFont.korean24:
        return 24;
    }
  }

  /// Approximate character height in millimeters at 203 DPI.
  double get heightMm => heightDots / 8.0;

  /// Approximate character width in millimeters at 203 DPI.
  double get widthMm => widthDots / 8.0;
}

/// 1D linear barcode symbologies supported by TSPL.
enum TsplBarcodeType {
  /// Code 128 (auto A/B/C) - Most common alphanumeric barcode.
  code128('128'),

  /// Code 39.
  code39('39'),

  /// Code 93.
  code93('93'),

  /// EAN-13 European / International Article Number.
  ean13('EAN13'),

  /// EAN-8 European / International Article Number.
  ean8('EAN8'),

  /// UPC-A Universal Product Code.
  upcA('UPCA'),

  /// UPC-E Universal Product Code.
  upcE('UPCE'),

  /// Interleaved 2 of 5.
  itf('ITF'),

  /// Codabar / NW-7.
  codabar('CODABAR');

  const TsplBarcodeType(this.commandName);

  /// Symbology string sent in the TSPL BARCODE command.
  final String commandName;
}

/// Human-readable text positioning for 1D barcodes.
enum TsplHumanReadable {
  /// Barcode only; no readable text printed.
  none(0),

  /// Human readable text printed below the barcode aligned to center.
  belowCenter(1),

  /// Human readable text printed above the barcode aligned to center.
  aboveCenter(2);

  const TsplHumanReadable(this.code);

  /// Code parameter sent to TSPL BARCODE command.
  final int code;
}

/// Error correction recovery level for TSPL QR codes.
enum TsplQrEcc {
  /// Low recovery (~7% correction).
  low('L'),

  /// Medium recovery (~15% correction, recommended default).
  medium('M'),

  /// Quality recovery (~25% correction).
  quality('Q'),

  /// High recovery (~30% correction).
  high('H');

  const TsplQrEcc(this.level);

  /// ECC level character sent in the TSPL QRCODE command.
  final String level;
}

/// Graphic composition mode for TSPL BITMAP drawing.
enum TsplBitmapMode {
  /// Overwrites target buffer pixels with the bitmap.
  overwrite(0),

  /// Bitwise ORs bitmap with the existing buffer.
  or(1),

  /// Bitwise XORs bitmap with the existing buffer.
  xor(2);

  const TsplBitmapMode(this.code);

  /// Mode integer parameter sent in the TSPL BITMAP command.
  final int code;
}

