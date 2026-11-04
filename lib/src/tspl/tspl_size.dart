/// Physical dimensions and resolution specifications for TSPL thermal label media.
class TsplSize {
  /// Creates a label size specification.
  ///
  /// [widthMm] and [heightMm] specify the physical width and height of the label in millimeters.
  /// [gapMm] specifies the gap between consecutive labels (defaults to 2.0 mm for standard die-cut labels).
  /// [dpi] is the printer resolution in dots per inch (defaults to standard 203 DPI = 8 dots/mm).
  const TsplSize({
    required this.widthMm,
    required this.heightMm,
    this.gapMm = 2.0,
    this.dpi = 203,
  })  : assert(widthMm > 0, 'widthMm must be positive.'),
        assert(heightMm > 0, 'heightMm must be positive.'),
        assert(gapMm >= 0, 'gapMm must be non-negative.');

  /// Label width in millimeters.
  final double widthMm;

  /// Label height in millimeters.
  final double heightMm;

  /// Distance between two labels in millimeters (0 for continuous paper).
  final double gapMm;

  /// Printer resolution in dots per inch (203 for 8 dots/mm, 300 for 12 dots/mm).
  final int dpi;

  /// Dots per millimeter based on [dpi].
  int get dotsPerMm => dpi == 300 ? 12 : 8;

  /// Label width converted to printer dots.
  int get widthDots => (widthMm * dotsPerMm).round();

  /// Label height converted to printer dots.
  int get heightDots => (heightMm * dotsPerMm).round();

  /// Gap converted to printer dots.
  int get gapDots => (gapMm * dotsPerMm).round();

  // ---------------------------------------------------------------------------
  // POPULAR DIE-CUT LABEL PRESETS
  // ---------------------------------------------------------------------------

  /// 20 mm × 30 mm: Jewelry, cable wrap, and tiny component labels.
  static const size20x30 = TsplSize(widthMm: 20, heightMm: 30, gapMm: 2.0);

  /// 30 mm × 20 mm: Compact price tags, pharmacy vial labels, and QR badges.
  static const size30x20 = TsplSize(widthMm: 30, heightMm: 20, gapMm: 2.0);

  /// 40 mm × 30 mm: Supermarket, grocery, and retail shelf price stickers.
  static const size40x30 = TsplSize(widthMm: 40, heightMm: 30, gapMm: 2.0);

  /// 50 mm × 30 mm: Inventory bin, asset tracking, and food container stickers.
  static const size50x30 = TsplSize(widthMm: 50, heightMm: 30, gapMm: 2.0);

  /// 60 mm × 40 mm: Standard product barcode, courier package, and dispatch labels.
  static const size60x40 = TsplSize(widthMm: 60, heightMm: 40, gapMm: 2.0);

  /// 70 mm × 50 mm: Medium warehouse box and dispatch carton stickers.
  static const size70x50 = TsplSize(widthMm: 70, heightMm: 50, gapMm: 2.0);

  /// 80 mm × 50 mm: Large retail and logistics shipping labels.
  static const size80x50 = TsplSize(widthMm: 80, heightMm: 50, gapMm: 2.0);

  /// 100 mm × 150 mm: Standard 4" × 6" international logistics and courier waybills.
  static const size100x150 = TsplSize(widthMm: 100, heightMm: 150, gapMm: 3.0);

  /// Returns a list of all standard preset sizes for UI dropdown selection.
  static const List<TsplSize> presets = [
    size20x30,
    size30x20,
    size40x30,
    size50x30,
    size60x40,
    size70x50,
    size80x50,
    size100x150,
  ];

  /// User-friendly label description, e.g. "40 × 30 mm (Shelf Tag)".
  String get name {
    final w = widthMm.toStringAsFixed(widthMm.truncateToDouble() == widthMm ? 0 : 1);
    final h = heightMm.toStringAsFixed(heightMm.truncateToDouble() == heightMm ? 0 : 1);
    if (widthMm == 20 && heightMm == 30) return '$w × $h mm (Jewelry/Cable)';
    if (widthMm == 30 && heightMm == 20) return '$w × $h mm (Small Price Tag)';
    if (widthMm == 40 && heightMm == 30) return '$w × $h mm (Retail Shelf Tag)';
    if (widthMm == 50 && heightMm == 30) return '$w × $h mm (Asset Tag)';
    if (widthMm == 60 && heightMm == 40) return '$w × $h mm (Barcode/Shipping)';
    if (widthMm == 70 && heightMm == 50) return '$w × $h mm (Warehouse Box)';
    if (widthMm == 80 && heightMm == 50) return '$w × $h mm (Logistics)';
    if (widthMm == 100 && heightMm == 150) return '$w × $h mm (4"×6" Waybill)';
    return '$w × $h mm (Custom)';
  }

  @override
  String toString() => '$name [${widthDots}x$heightDots dots]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TsplSize &&
          runtimeType == other.runtimeType &&
          widthMm == other.widthMm &&
          heightMm == other.heightMm &&
          gapMm == other.gapMm &&
          dpi == other.dpi;

  @override
  int get hashCode => Object.hash(widthMm, heightMm, gapMm, dpi);
}
