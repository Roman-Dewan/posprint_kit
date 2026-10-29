import 'dart:typed_data';

import 'code_pages.dart';
import 'ops.dart';
import 'printer_profile.dart';
import 'text_metrics.dart';

/// Decision engine for determining whether text should be printed natively
/// or rasterized into an image, and formatting text into fixed-column rows.
class TextEngine {
  TextEngine(this.profile);

  final PrinterProfile profile;

  /// Decides whether a given text operation should be executed natively or rendered to an image.
  bool shouldRenderAsImage(String text, TextMode mode) {
    switch (mode) {
      case TextMode.image:
        return true;
      case TextMode.native:
        return false;
      case TextMode.auto:
        return !canPrintNatively(text);
    }
  }

  /// Checks if every character in [text] can be natively printed by the printer
  /// using any of the code pages in [profile.codePages].
  bool canPrintNatively(String text) {
    for (final codePage in profile.codePages) {
      final encoder = CodePageEncoder(codePage);
      if (encoder.canEncode(text)) {
        return true;
      }
    }
    return false;
  }

  /// Finds the first code page in [profile.codePages] that can encode [text].
  /// Returns `null` if none can.
  CodePage? findMatchingCodePage(String text) {
    for (final codePage in profile.codePages) {
      final encoder = CodePageEncoder(codePage);
      if (encoder.canEncode(text)) {
        return codePage;
      }
    }
    return null;
  }

  /// Encodes [text] to bytes using the best matching code page from [profile.codePages].
  /// Throws [FormatException] if no code page supports all characters in [text].
  (CodePage, Uint8List) encodeNative(String text) {
    for (final codePage in profile.codePages) {
      final encoder = CodePageEncoder(codePage);
      if (encoder.canEncode(text)) {
        return (codePage, encoder.encode(text));
      }
    }

    throw FormatException(
      'Text contains characters not encodable by any code page in the profile (${profile.codePages}). '
      'Use TextMode.image or TextMode.auto to render multilingual scripts as images.',
    );
  }

  /// Formats a two-column row ([left], [right]) into a single native monospace line.
  ///
  /// Uses [TextMetrics.columnWidth] so full-width CJK characters correctly count
  /// as 2 columns.
  String formatNativeRow(String left, String right, {int? columns}) {
    final cols = columns ?? profile.columnsNormal;
    final leftWidth = TextMetrics.columnWidth(left);
    final rightWidth = TextMetrics.columnWidth(right);

    final spacesAvailable = cols - leftWidth - rightWidth;
    if (spacesAvailable >= 1) {
      return '$left${' ' * spacesAvailable}$right\n';
    }

    // If left text is too long, wrap it onto multiple lines
    final maxLeftCols = cols - rightWidth - 1;
    if (maxLeftCols > 0) {
      final truncatedLeft = _wrapOrTruncate(left, maxLeftCols);
      final padding = cols - TextMetrics.columnWidth(truncatedLeft) - rightWidth;
      return '$truncatedLeft${' ' * padding.clamp(1, cols)}$right\n';
    }

    // Fallback: put right text on a second line flush right
    final rightPadding = (cols - rightWidth).clamp(0, cols);
    return '$left\n${' ' * rightPadding}$right\n';
  }

  String _wrapOrTruncate(String text, int maxCols) {
    final buffer = StringBuffer();
    var currentWidth = 0;
    for (final rune in text.runes) {
      final charWidth = TextMetrics.isFullWidth(rune) ? 2 : 1;
      if (currentWidth + charWidth > maxCols) {
        break;
      }
      buffer.writeCharCode(rune);
      currentWidth += charWidth;
    }
    return buffer.toString();
  }
}

