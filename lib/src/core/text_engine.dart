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

  /// Formats a multi-column row (3, 4, 5+ columns) into native monospace lines
  /// with flex width distribution, column alignments, clean whitespace gaps,
  /// and graceful multi-line wrapping.
  String formatNativeColumns(List<PosColumn> columns, {int? totalColumns}) {
    if (columns.isEmpty) return '\n';

    final totalCols = totalColumns ?? profile.columnsNormal;
    final numCols = columns.length;

    // Minimum 1 character space gap between adjacent columns
    final totalGaps = numCols > 1 ? numCols - 1 : 0;
    final availableWidth = totalCols - totalGaps;
    if (availableWidth < numCols) {
      // Very narrow or too many columns: concatenate with single space
      return '${columns.map((c) => c.text).join(' ')}\n';
    }

    final totalFlex =
        columns.fold<int>(0, (sum, c) => sum + (c.width > 0 ? c.width : 1));

    // Allocate column widths based on flex ratios
    final colWidths = List<int>.filled(numCols, 1);
    var remainingWidth = availableWidth;

    for (var i = 0; i < numCols; i++) {
      final flex = columns[i].width > 0 ? columns[i].width : 1;
      final allocated = (availableWidth * flex) ~/ totalFlex;
      colWidths[i] = allocated > 0 ? allocated : 1;
      remainingWidth -= colWidths[i];
    }

    // Distribute any remainder characters
    var colIdx = 0;
    while (remainingWidth > 0) {
      colWidths[colIdx % numCols]++;
      remainingWidth--;
      colIdx++;
    }
    while (remainingWidth < 0) {
      for (var i = numCols - 1; i >= 0 && remainingWidth < 0; i--) {
        if (colWidths[i] > 1) {
          colWidths[i]--;
          remainingWidth++;
        }
      }
      break;
    }

    // Wrap each column's text into wrapped lines for its assigned width
    final wrappedCells = <List<String>>[];
    var maxLines = 1;

    for (var i = 0; i < numCols; i++) {
      final cellLines = _wrapCellText(columns[i].text, colWidths[i]);
      wrappedCells.add(cellLines);
      if (cellLines.length > maxLines) {
        maxLines = cellLines.length;
      }
    }

    // Assemble lines
    final buffer = StringBuffer();
    for (var lineIdx = 0; lineIdx < maxLines; lineIdx++) {
      for (var colI = 0; colI < numCols; colI++) {
        if (colI > 0) {
          buffer.write(' '); // gap between columns
        }
        final text = lineIdx < wrappedCells[colI].length
            ? wrappedCells[colI][lineIdx]
            : '';
        final textColWidth = TextMetrics.columnWidth(text);
        final colWidth = colWidths[colI];
        final padding = (colWidth - textColWidth).clamp(0, totalCols);

        switch (columns[colI].align) {
          case PosAlign.left:
            buffer.write(text);
            buffer.write(' ' * padding);
          case PosAlign.right:
            buffer.write(' ' * padding);
            buffer.write(text);
          case PosAlign.center:
            final leftPad = padding ~/ 2;
            final rightPad = padding - leftPad;
            buffer.write(' ' * leftPad);
            buffer.write(text);
            buffer.write(' ' * rightPad);
        }
      }
      buffer.write('\n');
    }

    return buffer.toString();
  }

  List<String> _wrapCellText(String text, int maxCols) {
    if (text.isEmpty) return const [''];
    if (maxCols <= 1) {
      return text.runes.map((r) => String.fromCharCode(r)).toList();
    }

    final rawLines = text.split('\n');
    final result = <String>[];

    for (final rawLine in rawLines) {
      if (TextMetrics.columnWidth(rawLine) <= maxCols) {
        result.add(rawLine);
        continue;
      }

      final words = rawLine.split(' ');
      var currentLine = StringBuffer();
      var currentWidth = 0;

      for (final word in words) {
        final wordWidth = TextMetrics.columnWidth(word);
        if (wordWidth > maxCols) {
          if (currentWidth > 0) {
            result.add(currentLine.toString());
            currentLine = StringBuffer();
            currentWidth = 0;
          }
          var charBuffer = StringBuffer();
          var charWidthAcc = 0;
          for (final rune in word.runes) {
            final rw = TextMetrics.isFullWidth(rune) ? 2 : 1;
            if (charWidthAcc + rw > maxCols && charWidthAcc > 0) {
              result.add(charBuffer.toString());
              charBuffer = StringBuffer();
              charWidthAcc = 0;
            }
            charBuffer.writeCharCode(rune);
            charWidthAcc += rw;
          }
          if (charBuffer.isNotEmpty) {
            currentLine = charBuffer;
            currentWidth = charWidthAcc;
          }
        } else {
          final spaceNeeded = currentWidth > 0 ? 1 : 0;
          if (currentWidth + spaceNeeded + wordWidth <= maxCols) {
            if (spaceNeeded > 0) currentLine.write(' ');
            currentLine.write(word);
            currentWidth += spaceNeeded + wordWidth;
          } else {
            result.add(currentLine.toString());
            currentLine = StringBuffer(word);
            currentWidth = wordWidth;
          }
        }
      }
      if (currentLine.isNotEmpty) {
        result.add(currentLine.toString());
      }
    }

    return result.isEmpty ? const [''] : result;
  }
}

