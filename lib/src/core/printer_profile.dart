import 'code_pages.dart';

/// Defines physical and logical capabilities of a thermal printer model.
///
/// Controls paper width in dots, character columns for native text, supported
/// code pages, and image band heights.
class PrinterProfile {
  const PrinterProfile({
    required this.dotsWidth,
    this.columnsNormal = 48,
    this.columnsCondensed = 64,
    this.codePages = const [CodePage.cp437],
    this.hasChineseFont = false,
    this.hasJapaneseFont = false,
    this.hasKoreanFont = false,
    this.maxBandRows = 128,
    this.supportsPartialCut = true,
  });

  /// The horizontal printing resolution of the thermal head in dots (pixels).
  ///
  /// Typically 384 dots for 58 mm printers and 576 dots (sometimes 512) for 80 mm printers.
  final int dotsWidth;

  /// Number of standard characters per line in normal font (Font A, 12x24 dots).
  ///
  /// Typically 32 on 58 mm paper and 42-48 on 80 mm paper.
  final int columnsNormal;

  /// Number of condensed characters per line in small font (Font B, 9x17 dots).
  ///
  /// Typically 42 on 58 mm paper and 56-64 on 80 mm paper.
  final int columnsCondensed;

  /// The list of character code pages supported by this printer model in order of preference.
  final List<CodePage> codePages;

  /// Whether the printer has built-in hardware Chinese fonts (e.g. GBK/Big5).
  final bool hasChineseFont;

  /// Whether the printer has built-in hardware Japanese fonts (e.g. Shift-JIS).
  final bool hasJapaneseFont;

  /// Whether the printer has built-in hardware Korean fonts (e.g. EUC-KR).
  final bool hasKoreanFont;

  /// Maximum pixel rows sent in a single `GS v 0` raster command to avoid overflowing
  /// the printer's receive buffer. Defaults to 128.
  final int maxBandRows;

  /// Whether this printer model's cutter mechanism supports partial cuts.
  final bool supportsPartialCut;

  /// Default profile for standard 80 mm thermal receipt printers (576 dots wide, 48 columns).
  static const generic80 = PrinterProfile(
    dotsWidth: 576,
    columnsNormal: 48,
    columnsCondensed: 64,
  );

  /// Default profile for portable and compact 58 mm thermal receipt printers (384 dots wide, 32 columns).
  static const generic58 = PrinterProfile(
    dotsWidth: 384,
    columnsNormal: 32,
    columnsCondensed: 42,
  );

  /// Preset for Epson TM-T20 series (80 mm).
  static const epsonTmT20 = PrinterProfile(
    dotsWidth: 576,
    columnsNormal: 48,
    columnsCondensed: 64,
    codePages: [CodePage.cp437, CodePage.cp858, CodePage.cp1252],
    supportsPartialCut: true,
  );

  /// Preset for Xprinter XP-58 series (58 mm).
  static const xprinter58 = PrinterProfile(
    dotsWidth: 384,
    columnsNormal: 32,
    columnsCondensed: 42,
    codePages: [CodePage.cp437],
    supportsPartialCut: false,
  );

  @override
  String toString() =>
      'PrinterProfile(dots: $dotsWidth, cols: $columnsNormal, maxBandRows: $maxBandRows)';
}

