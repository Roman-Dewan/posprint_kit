import 'dart:convert';
import 'dart:typed_data';

import '../core/raster.dart';
import '../core/text_rasterizer.dart';
import 'tspl_enums.dart';
import 'tspl_label.dart';
import 'tspl_ops.dart';

/// Compiles a [TsplLabel] into binary TSPL byte commands conforming to
/// the TSC TSPL/TSPL2 programming specification.
class TsplEncoder {
  const TsplEncoder({this.rasterizer});

  /// Pluggable text rasterizer for rendering complex multilingual scripts
  /// (Bangla, Arabic, Hindi, CJK, etc.) into 1-bit monochrome bitmaps.
  final TextRasterizer? rasterizer;

  /// Compiles [label] into raw binary TSPL commands ready for transmission.
  Future<Uint8List> encode(TsplLabel label) async {
    final builder = BytesBuilder(copy: false);

    // 1. Label dimensions: SIZE width mm, height mm
    final widthStr = _formatMm(label.size.widthMm);
    final heightStr = _formatMm(label.size.heightMm);
    _writeAscii(builder, 'SIZE $widthStr mm, $heightStr mm\r\n');

    // 2. Gap: GAP distance mm, offset mm
    final gapMm = label.customGapMm ?? label.size.gapMm;
    _writeAscii(builder, 'GAP ${_formatMm(gapMm)} mm, 0 mm\r\n');

    // 3. Direction
    _writeAscii(builder, 'DIRECTION ${label.direction.code}\r\n');

    // 4. Origin reference
    _writeAscii(builder, 'REFERENCE ${label.referenceX}, ${label.referenceY}\r\n');

    // 5. Optional speed and density
    if (label.speed != null) {
      _writeAscii(builder, 'SPEED ${label.speed}\r\n');
    }
    if (label.density != null) {
      _writeAscii(builder, 'DENSITY ${label.density}\r\n');
    }

    // 6. Clear image buffer (mandatory before drawing)
    _writeAscii(builder, 'CLS\r\n');

    // 7. Render each visual element
    for (final op in label.ops) {
      await _encodeOp(builder, op, label);
    }

    // 8. Auto cut if requested
    if (label.autoCut) {
      _writeAscii(builder, 'CUT\r\n');
    }

    // 9. Trigger print: PRINT copies, 1
    final copies = label.copies > 0 ? label.copies : 1;
    _writeAscii(builder, 'PRINT $copies, 1\r\n');

    return builder.takeBytes();
  }

  Future<void> _encodeOp(
    BytesBuilder builder,
    TsplOp op,
    TsplLabel label,
  ) async {
    switch (op) {
      case TsplTextOp():
        final escaped = op.text.replaceAll('"', r'\"');
        _writeAscii(
          builder,
          'TEXT ${op.x}, ${op.y}, "${op.font.commandName}", ${op.rotation.degrees}, '
          '${op.xMultiplication}, ${op.yMultiplication}, "$escaped"\r\n',
        );

      case TsplBarcodeOp():
        final escaped = op.data.replaceAll('"', r'\"');
        _writeAscii(
          builder,
          'BARCODE ${op.x}, ${op.y}, "${op.type.commandName}", ${op.height}, '
          '${op.humanReadable.code}, ${op.rotation.degrees}, ${op.narrow}, ${op.wide}, "$escaped"\r\n',
        );

      case TsplQrOp():
        final escaped = op.data.replaceAll('"', r'\"');
        _writeAscii(
          builder,
          'QRCODE ${op.x}, ${op.y}, ${op.ecc.level}, ${op.size}, A, ${op.rotation.degrees}, "$escaped"\r\n',
        );

      case TsplBoxOp():
        if (op.radius != null && op.radius! > 0) {
          _writeAscii(
            builder,
            'BOX ${op.x}, ${op.y}, ${op.endX}, ${op.endY}, ${op.thickness}, ${op.radius}\r\n',
          );
        } else {
          _writeAscii(
            builder,
            'BOX ${op.x}, ${op.y}, ${op.endX}, ${op.endY}, ${op.thickness}\r\n',
          );
        }

      case TsplBarOp():
        _writeAscii(builder, 'BAR ${op.x}, ${op.y}, ${op.width}, ${op.height}\r\n');

      case TsplReverseOp():
        _writeAscii(builder, 'REVERSE ${op.x}, ${op.y}, ${op.width}, ${op.height}\r\n');

      case TsplBitmapOp():
        _encodeBitmap(builder, op.bitmap, op.x, op.y, op.mode);

      case TsplRasterTextOp():
        if (rasterizer != null) {
          final maxW = op.maxWidth ?? (label.size.widthDots - op.x).clamp(16, 2048);
          final gray = await rasterizer!.renderText(
            op.text,
            widthDots: maxW,
            style: TextStyleSpec(
              fontSize: op.fontSize,
              bold: op.bold,
              fontFamily: op.fontFamily,
            ),
            languageTag: op.languageTag,
          );
          final mono = gray.toMono();
          _encodeBitmap(builder, mono, op.x, op.y, TsplBitmapMode.overwrite);
        } else {
          // Fallback to native text if no rasterizer provided
          final escaped = op.text.replaceAll('"', r'\"');
          _writeAscii(
            builder,
            'TEXT ${op.x}, ${op.y}, "${TsplFont.font3.commandName}", 0, 1, 1, "$escaped"\r\n',
          );
        }
    }
  }

  void _encodeBitmap(
    BytesBuilder builder,
    MonoBitmap bitmap,
    int x,
    int y,
    TsplBitmapMode mode,
  ) {
    // TSPL format: BITMAP X, Y, width_in_bytes, height_in_dots, mode, <binary_data>\r\n
    final widthBytes = bitmap.bytesPerLine;
    final heightDots = bitmap.height;
    _writeAscii(builder, 'BITMAP $x, $y, $widthBytes, $heightDots, ${mode.code},');
    builder.add(bitmap.data);
    _writeAscii(builder, '\r\n');
  }

  void _writeAscii(BytesBuilder builder, String command) {
    builder.add(utf8.encode(command));
  }

  String _formatMm(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
