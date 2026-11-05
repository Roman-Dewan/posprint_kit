import '../core/raster.dart';
import 'tspl_enums.dart';
import 'tspl_ops.dart';
import 'tspl_size.dart';

/// A fluent builder for creating coordinate-based sticker labels and barcodes
/// using TSPL (TSC Printer Language).
///
/// Coordinate system:
/// - `horizontal` (or `x`): Distance from the left edge of the sticker in dots.
/// - `vertical` (or `y`): Distance from the top edge of the sticker in dots.
/// - Or use the `*Mm` helper methods (`textMm`, `barcodeMm`, `boxMm`, etc.)
///   to specify positions directly in physical millimeters without doing math!
///
/// Example:
/// ```dart
/// final label = TsplLabel(size: TsplSize.size40x30)
///   ..boxMm(horizontal: 1, vertical: 1, endHorizontal: 39, endVertical: 29)
///   ..textMm('ORGANIC STORE', horizontal: 2, vertical: 2, font: TsplFont.font3)
///   ..lineMm(horizontal: 2, vertical: 6, width: 36)
///   ..textRasterMm('টাটকা রুটি', horizontal: 2, vertical: 8, fontSize: 16, languageTag: 'bn')
///   ..barcodeMm('20491024', horizontal: 2, vertical: 14, height: 6)
///   ..qrMm('https://posprint.example.com', horizontal: 25, vertical: 14, size: 3)
///   ..textMm('PRICE: \$4.50', horizontal: 2, vertical: 23, font: TsplFont.font4)
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

  /// Origin reference horizontal offset in dots (left).
  int referenceX;

  /// Origin reference vertical offset in dots (top).
  int referenceY;

  /// Print speed in inches/sec (2 to 6, optional).
  int? speed;

  /// Darkness/density setting (0 to 15, optional).
  int? density;

  /// Number of copies to print when executed.
  int copies;

  /// Whether to issue a paper cut command at the end of printing.
  bool autoCut;

  /// Current vertical pen position in millimeters for auto-flow layout.
  double _cursorVerticalMm = 2.5;

  /// Default margin in millimeters for auto-flow layout (left, right, and top offset).
  double marginMm = 2.5;

  /// Returns the current vertical cursor position in millimeters.
  double get cursorVerticalMm => _cursorVerticalMm;

  /// The list of visual elements placed on the label.
  final List<TsplOp> ops = [];

  /// Creates a ready-to-print restaurant / kitchen token order sticker.
  ///
  /// Matches standard order tags (e.g. 60×40 mm) with zero manual coordinate math,
  /// and automatically adjusts fonts, margins, and line gaps based on the label dimensions.
  ///
  /// Example:
  /// ```dart
  /// final label = TsplLabel.token(
  ///   tokenNumber: '027',
  ///   date: '11/05/2026',
  ///   guest: 'Walk-in',
  ///   sequence: '2 of 2',
  ///   item: 'Salcoty SMALL',
  ///   addons: const ['Sugar Free', 'moglai', 'onion fry'],
  ///   specialInstructions: 'add more suger, suger free',
  ///   note: 'test dfef cvvvcdd bbbbb vvg nnnnn cccc mmmm zzz',
  /// );
  /// ```
  factory TsplLabel.token({
    required String tokenNumber,
    String? date,
    String? guest,
    String? sequence,
    String? item,
    List<String>? items,
    dynamic addons,
    String? specialInstructions,
    String? si,
    String? note,
    List<String>? notes,
    TsplSize size = TsplSize.size60x40,
    double? marginMm,
  }) {
    final label = TsplLabel(size: size);

    // Dynamically scale fonts, gaps, and margins based on label dimensions:
    final w = size.widthMm;
    final h = size.heightMm;
    final isCompact = w < 48.0 || h < 35.0; // e.g. 40x30, 30x20
    final isLarge = w >= 70.0 || h >= 50.0;   // e.g. 70x50, 80x50, 40x60

    final effectiveMargin = marginMm ?? (isCompact ? 1.5 : (isLarge ? 3.5 : 2.5));
    final headerFont = isCompact ? TsplFont.font2 : (isLarge ? TsplFont.font4 : TsplFont.font3);
    final subHeaderFont = isCompact ? TsplFont.font1 : (isLarge ? TsplFont.font3 : TsplFont.font2);
    final itemFont = isCompact ? TsplFont.font2 : (isLarge ? TsplFont.font4 : TsplFont.font3);
    final detailsFont = isCompact ? TsplFont.font1 : (isLarge ? TsplFont.font3 : TsplFont.font2);

    final lineGap = isCompact ? 0.8 : (isLarge ? 2.2 : 1.2);
    final dividerGapBefore = isCompact ? 0.6 : (isLarge ? 1.5 : 1.0);
    final dividerGapAfter = isCompact ? 1.0 : (isLarge ? 3.0 : 2.0);

    label.marginMm = effectiveMargin;
    label.cursorMm(effectiveMargin);

    final tokenText = tokenNumber.toUpperCase().startsWith('TOKEN')
        ? tokenNumber
        : 'TOKEN - $tokenNumber';

    final dateText = date ?? _currentDateFormatted();

    // 1. Header Row 1: TOKEN - 027 (left) | 11/05/2026 (right)
    label.rowMm(
      left: tokenText,
      right: dateText,
      font: headerFont,
      spacingAfter: lineGap,
    );

    // 2. Header Row 2: Guest : Walk-in (left) | 2 of 2 (right)
    if ((guest != null && guest.isNotEmpty) || (sequence != null && sequence.isNotEmpty)) {
      final guestText = guest != null && guest.isNotEmpty
          ? (guest.startsWith('Guest') ? guest : 'Guest : $guest')
          : '';
      label.rowMm(
        left: guestText,
        right: sequence,
        font: subHeaderFont,
        spacingAfter: lineGap,
      );
    }

    // 3. Crisp horizontal divider line across the sticker
    label.dividerMm(
      thickness: 1,
      spacingBefore: dividerGapBefore,
      spacingAfter: dividerGapAfter,
    );

    // 4. Item Name: Salcoty SMALL
    final allItems = <String>[];
    if (item != null && item.isNotEmpty) allItems.add(item);
    if (items != null) allItems.addAll(items);
    if (allItems.isEmpty) allItems.add('Item');

    for (final it in allItems) {
      label.textLineMm(it, font: itemFont, spacingAfter: lineGap + 0.5);
    }

    // 5. Addons: Addon: Sugar Free, moglai,\n       onion fry
    if (addons is List) {
      final itemsList = addons.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (itemsList.isNotEmpty) {
        const prefix = 'Addon: ';
        final indent = ' ' * prefix.length;
        var current = StringBuffer(prefix);
        var isFirstLine = true;
        final maxChars = ((w - (effectiveMargin * 2)) / (detailsFont.widthMm * 1.1)).floor().clamp(10, 200);

        for (var i = 0; i < itemsList.length; i++) {
          final itemStr = itemsList[i] + (i < itemsList.length - 1 ? ',' : '');
          final neededLen = current.length +
              (current.length > (isFirstLine ? prefix.length : indent.length) ? 1 : 0) +
              itemStr.length;

          if (neededLen <= maxChars) {
            if (current.length > (isFirstLine ? prefix.length : indent.length)) current.write(' ');
            current.write(itemStr);
          } else {
            label.textLineMm(current.toString(), font: detailsFont, spacingAfter: 0.8);
            current = StringBuffer('$indent$itemStr');
            isFirstLine = false;
          }
        }
        if (current.isNotEmpty) {
          label.textLineMm(current.toString(), font: detailsFont, spacingAfter: lineGap);
        }
      }
    } else if (addons is String && addons.trim().isNotEmpty) {
      var addonText = addons.trim();
      if (!addonText.startsWith('Addon:')) {
        addonText = 'Addon: $addonText';
      }
      label.wrappedTextMm(
        addonText,
        font: detailsFont,
        indentMm: 7.0 * detailsFont.widthMm,
        spacingAfter: lineGap,
      );
    }

    // 6. Special Instructions: SI : add more suger, suger free
    final siText = (specialInstructions ?? si)?.trim();
    if (siText != null && siText.isNotEmpty) {
      final formattedSi = siText.startsWith('SI') ? siText : 'SI : $siText';
      label.wrappedTextMm(
        formattedSi,
        font: detailsFont,
        indentMm: 5.0 * detailsFont.widthMm,
        spacingAfter: lineGap,
      );
    }

    // 7. Order Note: Note: test dfef cvvvcdd bbbbb vvg\nnnnnn cccc mmmm zzz
    final noteLines = <String>[];
    if (note != null && note.trim().isNotEmpty) noteLines.add(note.trim());
    if (notes != null) noteLines.addAll(notes.map((e) => e.trim()).where((e) => e.isNotEmpty));

    for (var n in noteLines) {
      if (!n.startsWith('Note:') && !n.startsWith('-')) {
        n = 'Note: $n';
      }
      label.wrappedTextMm(
        n,
        font: detailsFont,
        spacingAfter: lineGap,
      );
    }

    return label;
  }

  static String _currentDateFormatted() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString();
    return '$d/$m/$y';
  }

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

  /// Sets or moves the vertical writing cursor in millimeters for auto-flow methods.
  TsplLabel cursorMm(double vertical) {
    _cursorVerticalMm = vertical;
    return this;
  }

  /// Sets the default margin in millimeters for auto-flow methods.
  TsplLabel setMarginMm(double margin) {
    marginMm = margin;
    return this;
  }

  /// Sets label gap distance and offset in millimeters.
  TsplLabel gap(double gapMm) {
    customGapMm = gapMm;
    return this;
  }

  /// Sets the coordinate origin offset in dots: [horizontal] (left) and [vertical] (top).
  TsplLabel reference(int horizontal, int vertical) {
    referenceX = horizontal;
    referenceY = vertical;
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
  // DOTS COORDINATE BUILDERS (Horizontal = X, Vertical = Y)
  // ---------------------------------------------------------------------------

  /// Adds a text element using built-in printer ROM fonts.
  ///
  /// [horizontal] (or [x]): Distance from the left edge in dots.
  /// [vertical] (or [y]): Distance from the top edge in dots.
  TsplLabel text(
    String text, {
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    TsplFont font = TsplFont.font3,
    TsplRotation rotation = TsplRotation.deg0,
    int xMultiplication = 1,
    int yMultiplication = 1,
  }) {
    ops.add(TsplTextOp(
      text: text,
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
      font: font,
      rotation: rotation,
      xMultiplication: xMultiplication,
      yMultiplication: yMultiplication,
    ));
    return this;
  }

  /// Adds a 1D linear barcode element.
  ///
  /// [horizontal] (or [x]): Distance from the left edge in dots.
  /// [vertical] (or [y]): Distance from the top edge in dots.
  TsplLabel barcode(
    String data, {
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    TsplBarcodeType type = TsplBarcodeType.code128,
    required int height,
    TsplHumanReadable humanReadable = TsplHumanReadable.belowCenter,
    TsplRotation rotation = TsplRotation.deg0,
    int narrow = 2,
    int wide = 2,
  }) {
    ops.add(TsplBarcodeOp(
      data: data,
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
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
  /// [horizontal] (or [x]): Distance from the left edge in dots.
  /// [vertical] (or [y]): Distance from the top edge in dots.
  /// [size]: Module cell width in dots (1 to 16, default 4).
  TsplLabel qr(
    String data, {
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    int size = 4,
    TsplQrEcc ecc = TsplQrEcc.medium,
    TsplRotation rotation = TsplRotation.deg0,
  }) {
    ops.add(TsplQrOp(
      data: data,
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
      size: size,
      ecc: ecc,
      rotation: rotation,
    ));
    return this;
  }

  /// Draws a rectangular border box.
  ///
  /// [horizontal] (or [x]): Left edge coordinate in dots.
  /// [vertical] (or [y]): Top edge coordinate in dots.
  /// [endHorizontal] (or [endX]): Right edge coordinate in dots.
  /// [endVertical] (or [endY]): Bottom edge coordinate in dots.
  TsplLabel box({
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    int? endHorizontal,
    int? endVertical,
    int? endX,
    int? endY,
    int thickness = 2,
    int? radius,
  }) {
    ops.add(TsplBoxOp(
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
      endHorizontal: endHorizontal ?? endX ?? (horizontal ?? x ?? 0),
      endVertical: endVertical ?? endY ?? (vertical ?? y ?? 0),
      thickness: thickness,
      radius: radius,
    ));
    return this;
  }

  /// Draws a solid horizontal or vertical bar.
  ///
  /// [horizontal] (or [x]): Distance from the left edge in dots.
  /// [vertical] (or [y]): Distance from the top edge in dots.
  TsplLabel bar({
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    required int width,
    required int height,
  }) {
    ops.add(TsplBarOp(
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
      width: width,
      height: height,
    ));
    return this;
  }

  /// Helper to draw a horizontal dividing line across the label.
  ///
  /// [horizontal] (or [x]): Distance from the left edge in dots.
  /// [vertical] (or [y]): Distance from the top edge in dots.
  TsplLabel line({
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    required int width,
    int thickness = 2,
  }) {
    return bar(
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
      width: width,
      height: thickness,
    );
  }

  /// Inverts colors (white on black) in the specified rectangular region.
  TsplLabel reverse({
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    required int width,
    required int height,
  }) {
    ops.add(TsplReverseOp(
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
      width: width,
      height: height,
    ));
    return this;
  }

  /// Draws a 1-bit monochrome bitmap onto the label.
  TsplLabel image(
    MonoBitmap bitmap, {
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    TsplBitmapMode mode = TsplBitmapMode.overwrite,
  }) {
    ops.add(TsplBitmapOp(
      bitmap: bitmap,
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
      mode: mode,
    ));
    return this;
  }

  /// Renders complex multilingual text (Bangla, Arabic, Hindi, CJK, etc.)
  /// into a 1-bit raster graphic and draws it using TSPL `BITMAP`.
  ///
  /// [horizontal] (or [x]): Distance from the left edge in dots.
  /// [vertical] (or [y]): Distance from the top edge in dots.
  TsplLabel textRaster(
    String text, {
    int? horizontal,
    int? vertical,
    int? x,
    int? y,
    double fontSize = 20.0,
    bool bold = false,
    String? fontFamily,
    String? languageTag,
    int? maxWidth,
  }) {
    ops.add(TsplRasterTextOp(
      text: text,
      horizontal: horizontal ?? x ?? 0,
      vertical: vertical ?? y ?? 0,
      fontSize: fontSize,
      bold: bold,
      fontFamily: fontFamily,
      languageTag: languageTag,
      maxWidth: maxWidth,
    ));
    return this;
  }

  // ---------------------------------------------------------------------------
  // MILLIMETER CONVENIENCE BUILDERS (Beginner-Friendly: No Math Required!)
  // ---------------------------------------------------------------------------

  /// Adds text using coordinates specified directly in **millimeters**.
  TsplLabel textMm(
    String text, {
    required double horizontal,
    required double vertical,
    TsplFont font = TsplFont.font3,
    TsplRotation rotation = TsplRotation.deg0,
    int xMultiplication = 1,
    int yMultiplication = 1,
  }) {
    return this.text(
      text,
      horizontal: size.mmToDots(horizontal),
      vertical: size.mmToDots(vertical),
      font: font,
      rotation: rotation,
      xMultiplication: xMultiplication,
      yMultiplication: yMultiplication,
    );
  }

  /// Adds a barcode using coordinates and height specified in **millimeters**.
  TsplLabel barcodeMm(
    String data, {
    required double horizontal,
    required double vertical,
    required double height,
    TsplBarcodeType type = TsplBarcodeType.code128,
    TsplHumanReadable humanReadable = TsplHumanReadable.belowCenter,
    TsplRotation rotation = TsplRotation.deg0,
    int narrow = 2,
    int wide = 2,
  }) {
    return barcode(
      data,
      horizontal: size.mmToDots(horizontal),
      vertical: size.mmToDots(vertical),
      height: size.mmToDots(height),
      type: type,
      humanReadable: humanReadable,
      rotation: rotation,
      narrow: narrow,
      wide: wide,
    );
  }

  /// Adds a QR code using coordinates specified in **millimeters**.
  TsplLabel qrMm(
    String data, {
    required double horizontal,
    required double vertical,
    int size = 4,
    TsplQrEcc ecc = TsplQrEcc.medium,
    TsplRotation rotation = TsplRotation.deg0,
  }) {
    return qr(
      data,
      horizontal: this.size.mmToDots(horizontal),
      vertical: this.size.mmToDots(vertical),
      size: size,
      ecc: ecc,
      rotation: rotation,
    );
  }

  /// Draws a rectangular box with coordinates in **millimeters**.
  TsplLabel boxMm({
    required double horizontal,
    required double vertical,
    required double endHorizontal,
    required double endVertical,
    int thickness = 2,
    double? radius,
  }) {
    return box(
      horizontal: size.mmToDots(horizontal),
      vertical: size.mmToDots(vertical),
      endHorizontal: size.mmToDots(endHorizontal),
      endVertical: size.mmToDots(endVertical),
      thickness: thickness,
      radius: radius != null ? size.mmToDots(radius) : null,
    );
  }

  /// Draws a horizontal line with coordinates and width in **millimeters**.
  TsplLabel lineMm({
    required double horizontal,
    required double vertical,
    required double width,
    int thickness = 2,
  }) {
    return line(
      horizontal: size.mmToDots(horizontal),
      vertical: size.mmToDots(vertical),
      width: size.mmToDots(width),
      thickness: thickness,
    );
  }

  /// Draws a solid bar with coordinates and dimensions in **millimeters**.
  TsplLabel barMm({
    required double horizontal,
    required double vertical,
    required double width,
    required double height,
  }) {
    return bar(
      horizontal: size.mmToDots(horizontal),
      vertical: size.mmToDots(vertical),
      width: size.mmToDots(width),
      height: size.mmToDots(height),
    );
  }

  /// Inverts color in a region specified in **millimeters**.
  TsplLabel reverseMm({
    required double horizontal,
    required double vertical,
    required double width,
    required double height,
  }) {
    return reverse(
      horizontal: size.mmToDots(horizontal),
      vertical: size.mmToDots(vertical),
      width: size.mmToDots(width),
      height: size.mmToDots(height),
    );
  }

  /// Renders multilingual text (Bangla, Arabic, Hindi, CJK, etc.) with coordinates in **millimeters**.
  TsplLabel textRasterMm(
    String text, {
    required double horizontal,
    required double vertical,
    double fontSize = 18.0,
    bool bold = false,
    String? fontFamily,
    String? languageTag,
    double? maxWidth,
  }) {
    return textRaster(
      text,
      horizontal: size.mmToDots(horizontal),
      vertical: size.mmToDots(vertical),
      fontSize: fontSize,
      bold: bold,
      fontFamily: fontFamily,
      languageTag: languageTag,
      maxWidth: maxWidth != null ? size.mmToDots(maxWidth) : null,
    );
  }

  // ---------------------------------------------------------------------------
  // AUTO-FLOW LAYOUT BUILDERS (Zero Coordinate Math!)
  // ---------------------------------------------------------------------------

  /// Adds a row with [left] text and optional right-aligned [right] text,
  /// then automatically advances the vertical cursor down.
  TsplLabel rowMm({
    required String left,
    String? right,
    TsplFont font = TsplFont.font3,
    double spacingAfter = 1.5,
  }) {
    // 1. Left text at current margin and cursor
    textMm(
      left,
      horizontal: marginMm,
      vertical: _cursorVerticalMm,
      font: font,
    );

    // 2. Right text aligned against right margin
    if (right != null && right.isNotEmpty) {
      final approxWidthMm = right.length * font.widthMm;
      final rightX = (size.widthMm - marginMm - approxWidthMm).clamp(marginMm, size.widthMm);
      textMm(
        right,
        horizontal: rightX,
        vertical: _cursorVerticalMm,
        font: font,
      );
    }

    // 3. Advance vertical cursor
    _cursorVerticalMm += font.heightMm + spacingAfter;
    return this;
  }

  /// Adds a single line of text at the current cursor and advances down.
  TsplLabel textLineMm(
    String text, {
    TsplFont font = TsplFont.font3,
    double spacingAfter = 1.5,
    int xMultiplication = 1,
    int yMultiplication = 1,
  }) {
    textMm(
      text,
      horizontal: marginMm,
      vertical: _cursorVerticalMm,
      font: font,
      xMultiplication: xMultiplication,
      yMultiplication: yMultiplication,
    );
    _cursorVerticalMm += (font.heightMm * yMultiplication) + spacingAfter;
    return this;
  }

  /// Draws a horizontal dividing line across the sticker and advances down.
  TsplLabel dividerMm({
    int thickness = 1,
    double spacingBefore = 1.0,
    double spacingAfter = 2.0,
  }) {
    _cursorVerticalMm += spacingBefore;
    lineMm(
      horizontal: marginMm,
      vertical: _cursorVerticalMm,
      width: size.widthMm - (marginMm * 2),
      thickness: thickness,
    );
    _cursorVerticalMm += spacingAfter;
    return this;
  }

  /// Advances the vertical cursor down by [heightMm].
  TsplLabel spaceMm(double heightMm) {
    _cursorVerticalMm += heightMm;
    return this;
  }

  /// Adds a line of multilingual raster text (Bangla, Arabic, Hindi, CJK, etc.)
  /// at the current cursor and advances down.
  TsplLabel textRasterLineMm(
    String text, {
    double fontSize = 14.0,
    bool bold = false,
    String? fontFamily,
    String? languageTag,
    double spacingAfter = 2.0,
  }) {
    textRasterMm(
      text,
      horizontal: marginMm,
      vertical: _cursorVerticalMm,
      fontSize: fontSize,
      bold: bold,
      fontFamily: fontFamily,
      languageTag: languageTag,
    );
    // Convert fontSize points to approximate mm height (~0.35 mm/pt)
    _cursorVerticalMm += (fontSize * 0.35) + spacingAfter;
    return this;
  }

  /// Adds a 1D barcode at the current cursor and advances down.
  TsplLabel barcodeLineMm(
    String data, {
    required double height,
    TsplBarcodeType type = TsplBarcodeType.code128,
    TsplHumanReadable humanReadable = TsplHumanReadable.belowCenter,
    double spacingAfter = 2.5,
    int narrow = 2,
    int wide = 2,
  }) {
    barcodeMm(
      data,
      horizontal: marginMm,
      vertical: _cursorVerticalMm,
      height: height,
      type: type,
      humanReadable: humanReadable,
      narrow: narrow,
      wide: wide,
    );
    _cursorVerticalMm += height + (humanReadable != TsplHumanReadable.none ? 3.5 : 0.0) + spacingAfter;
    return this;
  }

  /// Adds multi-line wrapped text that automatically breaks across lines
  /// to fit within [maxWidthMm] (defaults to remaining label width).
  ///
  /// Supports optional [indentMm] for hanging indents on wrapped lines.
  TsplLabel wrappedTextMm(
    String text, {
    TsplFont font = TsplFont.font2,
    double? maxWidthMm,
    double? indentMm,
    double spacingAfter = 1.2,
    double lineSpacing = 0.8,
  }) {
    final maxW = maxWidthMm ?? (size.widthMm - (marginMm * 2));
    final charPitchMm = font.widthMm * 1.1; // Takes inter-character pitch into account
    final maxChars = (maxW / charPitchMm).floor().clamp(10, 200);
    final indentChars = indentMm != null ? (indentMm / font.widthMm).floor() : 0;
    final indentPrefix = ' ' * indentChars;

    final lines = _wrapWords(text, maxChars: maxChars, indentPrefix: indentPrefix);
    for (var i = 0; i < lines.length; i++) {
      final isLast = i == lines.length - 1;
      textMm(
        lines[i],
        horizontal: marginMm,
        vertical: _cursorVerticalMm,
        font: font,
      );
      _cursorVerticalMm += font.heightMm + (isLast ? spacingAfter : lineSpacing);
    }
    return this;
  }

  static List<String> _wrapWords(String text, {required int maxChars, String indentPrefix = ''}) {
    final paragraphs = text.split('\n');
    final allLines = <String>[];

    for (final paragraph in paragraphs) {
      final words = paragraph.split(' ');
      var currentLine = StringBuffer();

      for (final word in words) {
        if (word.isEmpty) continue;
        final linePrefix = allLines.isEmpty ? '' : indentPrefix;
        final testLen = linePrefix.length + currentLine.length + (currentLine.isEmpty ? 0 : 1) + word.length;

        if (testLen <= maxChars) {
          if (currentLine.isNotEmpty) currentLine.write(' ');
          currentLine.write(word);
        } else {
          if (currentLine.isNotEmpty) {
            allLines.add((allLines.isEmpty ? '' : indentPrefix) + currentLine.toString());
            currentLine = StringBuffer(word);
          } else {
            allLines.add((allLines.isEmpty ? '' : indentPrefix) + word);
          }
        }
      }
      if (currentLine.isNotEmpty) {
        allLines.add((allLines.isEmpty ? '' : indentPrefix) + currentLine.toString());
      }
    }
    return allLines.isEmpty ? [text] : allLines;
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
