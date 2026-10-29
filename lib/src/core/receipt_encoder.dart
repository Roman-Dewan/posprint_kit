import 'dart:convert';
import 'dart:typed_data';

import 'code_pages.dart';
import 'commands.dart';
import 'ops.dart';
import 'printer_profile.dart';
import 'receipt.dart';
import 'result.dart';
import 'text_engine.dart';
import 'text_rasterizer.dart';

/// Transforms a high-level [Receipt] into raw ESC/POS printer byte commands.
///
/// Handles text formatting, code page selection, two-column row calculations,
/// and image band splitting.
class ReceiptEncoder {
  ReceiptEncoder(this.profile, this.rasterizer)
      : textEngine = TextEngine(profile);

  final PrinterProfile profile;
  final TextRasterizer rasterizer;
  final TextEngine textEngine;

  /// Turns [receipt] into printer bytes.
  ///
  /// If [init] is `true` (default), prepends hardware initialization `ESC @`.
  Future<Result<Uint8List>> encode(
    Receipt receipt, {
    bool init = true,
  }) async {
    final buffer = BytesBuilder(copy: false);

    if (init) {
      buffer.add(Commands.init);
    }

    CodePage currentCodePage = profile.codePages.isNotEmpty
        ? profile.codePages.first
        : CodePage.cp437;
    buffer.add(Commands.selectCodePage(currentCodePage.commandNumber));

    PosAlign currentAlign = PosAlign.left;
    bool currentBold = false;
    TextSize currentSize = TextSize.normal;

    for (final op in receipt.ops) {
      switch (op) {
        case TextOp(
            :final text,
            :final align,
            :final bold,
            :final size,
            :final mode,
            :final languageTag,
            :final style
          ):
          if (textEngine.shouldRenderAsImage(text, mode)) {
            // Multilingual image rendering
            try {
              final gray = await rasterizer.renderText(
                text,
                widthDots: profile.dotsWidth,
                style: style.bold || bold
                    ? TextStyleSpec(
                        fontSize: style.fontSize,
                        bold: true,
                        fontFamily: style.fontFamily,
                        fontFamilyFallback: style.fontFamilyFallback,
                        letterSpacing: style.letterSpacing,
                        lineHeight: style.lineHeight,
                      )
                    : style,
                align: align,
                languageTag: languageTag,
              );
              final mono = gray.toMono(threshold: 128);
              for (final band in mono.toBands(profile.maxBandRows)) {
                buffer.add(band.toEscPosBytes());
              }
            } catch (e) {
              return Result.error(
                PrinterError.renderFailed(reason: e.toString()),
              );
            }
          } else {
            // Native text printing
            if (align != currentAlign) {
              buffer.add(_alignBytes(align));
              currentAlign = align;
            }
            if (bold != currentBold) {
              buffer.add(bold ? Commands.boldOn : Commands.boldOff);
              currentBold = bold;
            }
            if (size != currentSize) {
              buffer.add(_sizeBytes(size));
              currentSize = size;
            }

            try {
              final (codePage, encodedBytes) = textEngine.encodeNative(text);
              if (codePage != currentCodePage) {
                buffer.add(Commands.selectCodePage(codePage.commandNumber));
                currentCodePage = codePage;
              }
              buffer.add(encodedBytes);
              buffer.addByte(Commands.lf);
            } catch (e) {
              return Result.error(
                PrinterError.renderFailed(reason: e.toString()),
              );
            }
          }

        case RowOp(
            :final left,
            :final right,
            :final bold,
            :final mode,
            :final languageTag,
            :final style
          ):
          final combined = '$left $right';
          if (textEngine.shouldRenderAsImage(combined, mode)) {
            // Render row in pixels so right-alignment and script shaping are exact
            try {
              final gray = await rasterizer.renderRow(
                left,
                right,
                widthDots: profile.dotsWidth,
                style: style.bold || bold
                    ? TextStyleSpec(
                        fontSize: style.fontSize,
                        bold: true,
                        fontFamily: style.fontFamily,
                        fontFamilyFallback: style.fontFamilyFallback,
                        letterSpacing: style.letterSpacing,
                        lineHeight: style.lineHeight,
                      )
                    : style,
                languageTag: languageTag,
              );
              final mono = gray.toMono(threshold: 128);
              for (final band in mono.toBands(profile.maxBandRows)) {
                buffer.add(band.toEscPosBytes());
              }
            } catch (e) {
              return Result.error(
                PrinterError.renderFailed(reason: e.toString()),
              );
            }
          } else {
            // Native monospace column formatting
            if (currentAlign != PosAlign.left) {
              buffer.add(Commands.alignLeft);
              currentAlign = PosAlign.left;
            }
            if (bold != currentBold) {
              buffer.add(bold ? Commands.boldOn : Commands.boldOff);
              currentBold = bold;
            }
            if (currentSize != TextSize.normal) {
              buffer.add(Commands.sizeNormal);
              currentSize = TextSize.normal;
            }

            final formattedRow = textEngine.formatNativeRow(left, right);
            try {
              final (codePage, encodedBytes) =
                  textEngine.encodeNative(formattedRow);
              if (codePage != currentCodePage) {
                buffer.add(Commands.selectCodePage(codePage.commandNumber));
                currentCodePage = codePage;
              }
              buffer.add(encodedBytes);
            } catch (e) {
              return Result.error(
                PrinterError.renderFailed(reason: e.toString()),
              );
            }
          }

        case DividerOp(:final character):
          if (currentAlign != PosAlign.left) {
            buffer.add(Commands.alignLeft);
            currentAlign = PosAlign.left;
          }
          if (currentBold) {
            buffer.add(Commands.boldOff);
            currentBold = false;
          }
          if (currentSize != TextSize.normal) {
            buffer.add(Commands.sizeNormal);
            currentSize = TextSize.normal;
          }

          final line = '${character * profile.columnsNormal}\n';
          buffer.add(ascii.encode(line));

        case FeedOp(:final lines):
          buffer.add(Commands.feedLines(lines));

        case CutOp(:final partial, :final feedDots):
          if (feedDots > 0) {
            buffer.add(Commands.feedLines(feedDots));
          }
          if (partial && profile.supportsPartialCut) {
            buffer.add(Commands.cutPartial);
          } else {
            buffer.add(Commands.cutFull);
          }

        case QrOp(:final data, :final size, :final errorCorrection):
          if (currentAlign != PosAlign.center) {
            buffer.add(Commands.alignCenter);
            currentAlign = PosAlign.center;
          }
          buffer.add(Commands.qrSelectModel2);
          buffer.add(Commands.qrModuleSize(size));
          buffer.add(Commands.qrErrorCorrection(errorCorrection.byteValue));
          buffer.add(Commands.qrStoreData(utf8.encode(data)));
          buffer.add(Commands.qrPrint);

          // Reset to left
          buffer.add(Commands.alignLeft);
          currentAlign = PosAlign.left;

        case BarcodeOp(:final data, :final type, :final height, :final width, :final hri):
          if (currentAlign != PosAlign.center) {
            buffer.add(Commands.alignCenter);
            currentAlign = PosAlign.center;
          }
          buffer.add(Commands.barcodeHeight(height));
          buffer.add(Commands.barcodeWidth(width));
          buffer.add(Commands.barcodeHri(hri));

          final typeByte = switch (type) {
            BarcodeType.code128 => 73, // 0x49
            BarcodeType.ean13 => 67, // 0x43
          };
          buffer.add(Commands.barcode(typeByte, ascii.encode(data)));

          buffer.add(Commands.alignLeft);
          currentAlign = PosAlign.left;

        case CashDrawerOp(:final pin5):
          buffer.add(pin5 ? Commands.cashDrawerPin5 : Commands.cashDrawerPin2);

        case ImageOp(:final bitmap):
          for (final band in bitmap.toBands(profile.maxBandRows)) {
            buffer.add(band.toEscPosBytes());
          }

        case RawBytesOp(:final bytes):
          buffer.add(bytes);
      }
    }

    // Reset styles at end of receipt
    if (currentBold) {
      buffer.add(Commands.boldOff);
    }
    if (currentSize != TextSize.normal) {
      buffer.add(Commands.sizeNormal);
    }
    if (currentAlign != PosAlign.left) {
      buffer.add(Commands.alignLeft);
    }

    return Result.ok(buffer.takeBytes());
  }

  List<int> _alignBytes(PosAlign align) => switch (align) {
        PosAlign.left => Commands.alignLeft,
        PosAlign.center => Commands.alignCenter,
        PosAlign.right => Commands.alignRight,
      };

  List<int> _sizeBytes(TextSize size) => switch (size) {
        TextSize.normal => Commands.sizeNormal,
        TextSize.doubleWidth => Commands.sizeDoubleWidth,
        TextSize.doubleHeight => Commands.sizeDoubleHeight,
        TextSize.doubleSize => Commands.sizeDouble,
      };
}

/// Helper used in tests to encode a receipt with [FakeRasterizer] and [PrinterProfile.generic80]
/// without initialization bytes.
Future<Uint8List> encodeForTest(
  Receipt receipt, {
  PrinterProfile profile = PrinterProfile.generic80,
  TextRasterizer rasterizer = const FakeRasterizer(),
  bool init = false,
}) async {
  final encoder = ReceiptEncoder(profile, rasterizer);
  final result = await encoder.encode(receipt, init: init);
  return result.when(
    ok: (bytes) => bytes,
    error: (err) => throw StateError('encodeForTest failed: ${err.message}'),
  );
}
