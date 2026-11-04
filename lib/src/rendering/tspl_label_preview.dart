import 'package:flutter/material.dart';

import '../tspl/tspl_enums.dart';
import '../tspl/tspl_label.dart';
import '../tspl/tspl_ops.dart';

/// A drop-in Flutter widget that renders a visual preview of a [TsplLabel]
/// sticker with true aspect ratio, rounded die-cut edges, and proportional layout.
///
/// Example:
/// ```dart
/// TsplLabelPreview(
///   label: TsplLabel(size: TsplSize.size40x30)
///     ..text('ORGANIC HONEY', x: 20, y: 20)
///     ..barcode('12345678', x: 20, y: 60, height: 40),
/// )
/// ```
class TsplLabelPreview extends StatelessWidget {
  const TsplLabelPreview({
    super.key,
    required this.label,
    this.maxWidth = 320.0,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFD0D7DE),
  });

  /// The label model to visualize.
  final TsplLabel label;

  /// Maximum display width of the preview card in logical pixels.
  final double maxWidth;

  /// Sticker background color.
  final Color backgroundColor;

  /// Border color of the sticker die-cut edge.
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final size = label.size;
    final aspectRatio = size.widthMm / size.heightMm;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dimension Header Tag
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      size.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF57606A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${size.widthDots} × ${size.heightDots} dots',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8C959F),
                    ),
                  ),
                ],
              ),
            ),

            // Physical Sticker Simulation Card
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8.0,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.5),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scaleX = constraints.maxWidth / size.widthDots;
                      final scaleY = constraints.maxHeight / size.heightDots;

                      return Stack(
                        children: [
                          for (final op in label.ops)
                            _buildOpWidget(op, scaleX, scaleY),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpWidget(TsplOp op, double scaleX, double scaleY) {
    switch (op) {
      case TsplTextOp():
        final fontSize = (12.0 * op.yMultiplication) * (scaleY * 2.0);
        return Positioned(
          left: op.x * scaleX,
          top: op.y * scaleY,
          child: Text(
            op.text,
            style: TextStyle(
              fontSize: fontSize.clamp(8.0, 36.0),
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'monospace',
            ),
          ),
        );

      case TsplRasterTextOp():
        final fontSize = op.fontSize * (scaleY * 1.5);
        return Positioned(
          left: op.x * scaleX,
          top: op.y * scaleY,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (op.maxWidth?.toDouble() ?? (label.size.widthDots - op.x).toDouble()) * scaleX,
            ),
            child: Text(
              op.text,
              style: TextStyle(
                fontSize: fontSize.clamp(8.0, 32.0),
                fontWeight: op.bold ? FontWeight.bold : FontWeight.normal,
                fontFamily: op.fontFamily,
                color: Colors.black,
              ),
            ),
          ),
        );

      case TsplBarcodeOp():
        return Positioned(
          left: op.x * scaleX,
          top: op.y * scaleY,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: op.height * scaleY,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 0.5),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    20,
                    (i) => Container(
                      width: i % 2 == 0 ? 1.5 : 2.5,
                      height: op.height * scaleY,
                      color: i % 3 == 0 ? Colors.white : Colors.black,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    ),
                  ),
                ),
              ),
              if (op.humanReadable != TsplHumanReadable.none)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: Text(
                    op.data,
                    style: TextStyle(
                      fontSize: (9.0 * scaleY * 2.0).clamp(7.0, 12.0),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );

      case TsplQrOp():
        final qrSize = (op.size * 25.0) * scaleX;
        return Positioned(
          left: op.x * scaleX,
          top: op.y * scaleY,
          child: Container(
            width: qrSize.clamp(24.0, 100.0),
            height: qrSize.clamp(24.0, 100.0),
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.0),
              color: Colors.white,
            ),
            child: const Icon(Icons.qr_code_2, size: 28, color: Colors.black),
          ),
        );

      case TsplBoxOp():
        final left = op.x * scaleX;
        final top = op.y * scaleY;
        final width = (op.endX - op.x) * scaleX;
        final height = (op.endY - op.y) * scaleY;
        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: op.radius != null
                  ? BorderRadius.circular(op.radius! * scaleX)
                  : null,
              border: Border.all(
                color: Colors.black,
                width: (op.thickness * scaleX).clamp(1.0, 4.0),
              ),
            ),
          ),
        );

      case TsplBarOp():
        return Positioned(
          left: op.x * scaleX,
          top: op.y * scaleY,
          width: op.width * scaleX,
          height: (op.height * scaleY).clamp(1.0, 100.0),
          child: Container(color: Colors.black),
        );

      case TsplReverseOp():
        return Positioned(
          left: op.x * scaleX,
          top: op.y * scaleY,
          width: op.width * scaleX,
          height: op.height * scaleY,
          child: Container(
            color: Colors.black,
          ),
        );

      case TsplBitmapOp():
        return Positioned(
          left: op.x * scaleX,
          top: op.y * scaleY,
          width: op.bitmap.width * scaleX,
          height: op.bitmap.height * scaleY,
          child: Container(
            color: Colors.black12,
            child: const Icon(Icons.image, size: 16, color: Colors.black54),
          ),
        );
    }
  }
}
