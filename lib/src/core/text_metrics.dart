/// Utility for measuring text column width in monospace thermal printer fonts.
///
/// In thermal printers, Latin and half-width characters occupy 1 column, while CJK
/// (Chinese, Japanese, Korean) full-width characters occupy 2 columns.
class TextMetrics {
  TextMetrics._();

  /// Calculates the display column width of [text] for monospace printer fonts.
  static int columnWidth(String text) {
    var width = 0;
    for (final rune in text.runes) {
      width += isFullWidth(rune) ? 2 : 1;
    }
    return width;
  }

  /// Returns `true` if [rune] is a full-width CJK or Asian ideograph/syllable.
  static bool isFullWidth(int rune) {
    // ASCII control characters or combining marks do not take standard space
    if (rune < 0x20 || (rune >= 0x7F && rune < 0xA0)) {
      return false;
    }

    // East Asian Wide / Fullwidth ranges
    return (rune >= 0x1100 && rune <= 0x115F) || // Hangul Jamo
        (rune >= 0x2E80 && rune <= 0x9FFF) || // CJK Radicals, Ideographs, Kangxi
        (rune >= 0xAC00 && rune <= 0xD7AF) || // Hangul Syllables
        (rune >= 0xF900 && rune <= 0xFAFF) || // CJK Compatibility Ideographs
        (rune >= 0xFE30 && rune <= 0xFE4F) || // CJK Compatibility Forms
        (rune >= 0xFF01 && rune <= 0xFF60) || // Fullwidth Forms
        (rune >= 0xFFE0 && rune <= 0xFFE6); // Fullwidth symbols
  }
}

