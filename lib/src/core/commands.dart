import 'dart:typed_data';

/// Standard ESC/POS command sequences and byte constants.
///
/// Every constant here is verified against official ESC/POS command specifications.
/// Do not guess command codes.
class Commands {
  Commands._();

  // ---------------------------------------------------------------------------
  // Control Characters
  // ---------------------------------------------------------------------------

  /// Null byte (NUL, 0x00).
  static const int nul = 0x00;

  /// Line Feed (LF, 0x0A): prints the data in the print buffer and feeds one line.
  static const int lf = 0x0A;

  /// Carriage Return (CR, 0x0D).
  static const int cr = 0x0D;

  /// Horizontal Tab (HT, 0x09).
  static const int ht = 0x09;

  /// Escape prefix (ESC, 0x1B).
  static const int esc = 0x1B;

  /// Group Separator (GS, 0x1D).
  static const int gs = 0x1D;

  /// File Separator (FS, 0x1C).
  static const int fs = 0x1C;

  /// Data Link Escape (DLE, 0x10).
  static const int dle = 0x10;

  // ---------------------------------------------------------------------------
  // Hardware and Initialization
  // ---------------------------------------------------------------------------

  /// ESC @: Initialize printer (clears print buffer and resets modes to power-on defaults).
  static const List<int> init = [0x1B, 0x40];

  /// ESC d n: Print and feed [n] lines (1 <= n <= 255).
  static Uint8List feedLines(int n) =>
      Uint8List.fromList([0x1B, 0x64, n.clamp(1, 255)]);

  // ---------------------------------------------------------------------------
  // Text Justification / Alignment (ESC a n)
  // ---------------------------------------------------------------------------

  /// ESC a 0: Align left.
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];

  /// ESC a 1: Align center.
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];

  /// ESC a 2: Align right.
  static const List<int> alignRight = [0x1B, 0x61, 0x02];

  // ---------------------------------------------------------------------------
  // Text Styles
  // ---------------------------------------------------------------------------

  /// ESC E 0: Emphasized / bold mode OFF.
  static const List<int> boldOff = [0x1B, 0x45, 0x00];

  /// ESC E 1: Emphasized / bold mode ON.
  static const List<int> boldOn = [0x1B, 0x45, 0x01];

  /// ESC - 0: Underline mode OFF.
  static const List<int> underlineOff = [0x1B, 0x2D, 0x00];

  /// ESC - 1: Underline mode ON (1-dot thin).
  static const List<int> underlineThin = [0x1B, 0x2D, 0x01];

  /// ESC - 2: Underline mode ON (2-dot thick).
  static const List<int> underlineThick = [0x1B, 0x2D, 0x02];

  // ---------------------------------------------------------------------------
  // Character Size (GS ! n)
  // n = (widthMultiplier - 1) << 4 | (heightMultiplier - 1)
  // ---------------------------------------------------------------------------

  /// GS ! 0x00: Normal size (1x width, 1x height).
  static const List<int> sizeNormal = [0x1D, 0x21, 0x00];

  /// GS ! 0x10: Double width (2x width, 1x height).
  static const List<int> sizeDoubleWidth = [0x1D, 0x21, 0x10];

  /// GS ! 0x01: Double height (1x width, 2x height).
  static const List<int> sizeDoubleHeight = [0x1D, 0x21, 0x01];

  /// GS ! 0x11: Double width and double height (2x width, 2x height).
  static const List<int> sizeDouble = [0x1D, 0x21, 0x11];

  /// Computes GS ! n for custom width and height multipliers (1 to 8).
  static Uint8List textSize({int width = 1, int height = 1}) {
    final w = (width.clamp(1, 8) - 1) << 4;
    final h = height.clamp(1, 8) - 1;
    return Uint8List.fromList([0x1D, 0x21, w | h]);
  }

  // ---------------------------------------------------------------------------
  // Paper Cutting (GS V)
  // ---------------------------------------------------------------------------

  /// GS V 0: Full paper cut.
  static const List<int> cutFull = [0x1D, 0x56, 0x00];

  /// GS V 1: Partial paper cut (leaves one point uncut so ticket does not drop).
  static const List<int> cutPartial = [0x1D, 0x56, 0x01];

  /// GS V 65 n: Feed [feedDots] dots and execute full cut.
  static Uint8List cutFullWithFeed(int feedDots) =>
      Uint8List.fromList([0x1D, 0x56, 0x41, feedDots.clamp(0, 255)]);

  /// GS V 66 n: Feed [feedDots] dots and execute partial cut.
  static Uint8List cutPartialWithFeed(int feedDots) =>
      Uint8List.fromList([0x1D, 0x56, 0x42, feedDots.clamp(0, 255)]);

  // ---------------------------------------------------------------------------
  // Cash Drawer Pulse (ESC p m t1 t2)
  // ---------------------------------------------------------------------------

  /// ESC p 0 25 250: Open cash drawer connected to pin 2.
  static const List<int> cashDrawerPin2 = [0x1B, 0x70, 0x00, 0x19, 0xFA];

  /// ESC p 1 25 250: Open cash drawer connected to pin 5.
  static const List<int> cashDrawerPin5 = [0x1B, 0x70, 0x01, 0x19, 0xFA];

  // ---------------------------------------------------------------------------
  // Code Page Selection (ESC t n)
  // ---------------------------------------------------------------------------

  /// ESC t n: Select character code page table [n].
  static Uint8List selectCodePage(int codePageNumber) =>
      Uint8List.fromList([0x1B, 0x74, codePageNumber & 0xFF]);

  // ---------------------------------------------------------------------------
  // QR Code (GS ( k)
  // ---------------------------------------------------------------------------

  /// GS ( k 4 0 49 65 50 0: Select QR code model 2.
  static const List<int> qrSelectModel2 = [
    0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
  ];

  /// GS ( k 3 0 49 67 [size]: Set QR module size (1 <= size <= 16).
  static Uint8List qrModuleSize(int size) => Uint8List.fromList([
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size.clamp(1, 16),
      ]);

  /// GS ( k 3 0 49 69 [level]: Set QR error correction level.
  /// L = 48 (7%), M = 49 (15%), Q = 50 (25%), H = 51 (30%).
  static Uint8List qrErrorCorrection(int levelByte) => Uint8List.fromList([
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, levelByte,
      ]);

  /// GS ( k pL pH 49 80 48 [data]: Store QR data in symbol storage area.
  static Uint8List qrStoreData(List<int> dataBytes) {
    final len = dataBytes.length + 3;
    final pL = len & 0xFF;
    final pH = (len >> 8) & 0xFF;
    final buffer = Uint8List(len + 5);
    buffer[0] = 0x1D;
    buffer[1] = 0x28;
    buffer[2] = 0x6B;
    buffer[3] = pL;
    buffer[4] = pH;
    buffer[5] = 0x31; // fn 49
    buffer[6] = 0x50; // fn 80
    buffer[7] = 0x30; // 48
    buffer.setRange(8, 8 + dataBytes.length, dataBytes);
    return buffer;
  }

  /// GS ( k 3 0 49 81 48: Print the QR code data stored in the symbol storage area.
  static const List<int> qrPrint = [
    0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
  ];

  // ---------------------------------------------------------------------------
  // Barcode Commands
  // ---------------------------------------------------------------------------

  /// GS h n: Set barcode height (1 <= n <= 255 dots). Default is 64.
  static Uint8List barcodeHeight(int heightDots) =>
      Uint8List.fromList([0x1D, 0x68, heightDots.clamp(1, 255)]);

  /// GS w n: Set barcode module width (2 <= n <= 6).
  static Uint8List barcodeWidth(int moduleWidth) =>
      Uint8List.fromList([0x1D, 0x77, moduleWidth.clamp(2, 6)]);

  /// GS H n: Set HRI (human readable interpretation) characters position:
  /// 0 = None, 1 = Above, 2 = Below, 3 = Both.
  static Uint8List barcodeHri(int position) =>
      Uint8List.fromList([0x1D, 0x48, position.clamp(0, 3)]);

  /// GS k m n [data]: Print barcode using Function B format.
  /// [barcodeTypeByte]: e.g. 73 for CODE128, 67 for EAN13.
  static Uint8List barcode(int barcodeTypeByte, List<int> dataBytes) {
    final buffer = Uint8List(4 + dataBytes.length);
    buffer[0] = 0x1D;
    buffer[1] = 0x6B;
    buffer[2] = barcodeTypeByte;
    buffer[3] = dataBytes.length & 0xFF;
    buffer.setRange(4, 4 + dataBytes.length, dataBytes);
    return buffer;
  }

  // ---------------------------------------------------------------------------
  // Raster Bit Image (GS v 0)
  // ---------------------------------------------------------------------------

  /// GS v 0 m xL xH yL yH: Header for 1-bit raster graphics.
  /// [bytesPerLine] = ceil(widthDots / 8) -> xL, xH
  /// [heightDots] -> yL, yH
  static Uint8List rasterHeader({
    required int bytesPerLine,
    required int heightDots,
    int mode = 0x00, // 0: normal, 1: double-width, 2: double-height, 3: quadruple
  }) {
    final xL = bytesPerLine & 0xFF;
    final xH = (bytesPerLine >> 8) & 0xFF;
    final yL = heightDots & 0xFF;
    final yH = (heightDots >> 8) & 0xFF;
    return Uint8List.fromList([
      0x1D, 0x76, 0x30, mode & 0x03, xL, xH, yL, yH,
    ]);
  }
}

