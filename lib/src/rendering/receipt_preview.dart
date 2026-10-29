import 'package:flutter/material.dart';

import '../core/ops.dart';
import '../core/printer_profile.dart';
import '../core/receipt.dart';

/// An on-screen visual preview widget that renders a [Receipt] exactly as it would appear
/// on thermal paper without burning rolls or needing a physical printer.
class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({
    super.key,
    required this.receipt,
    this.profile = PrinterProfile.generic80,
    this.backgroundColor = const Color(0xFFFBFBFB),
    this.elevation = 4.0,
  });

  /// The receipt to visualize.
  final Receipt receipt;

  /// Target printer profile determining paper width (58 mm ~ 384 dots, 80 mm ~ 576 dots).
  final PrinterProfile profile;

  /// Background paper color (warm white by default).
  final Color backgroundColor;

  /// Visual paper card elevation shadow.
  final double elevation;

  @override
  Widget build(BuildContext context) {
    // Approximate display width based on printer dots (scale to sensible screen pt)
    final displayWidth = profile.dotsWidth > 400 ? 340.0 : 260.0;

    return Center(
      child: Material(
        elevation: elevation,
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4.0),
        child: Container(
          width: displayWidth,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final op in receipt.ops) _buildOpWidget(op),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpWidget(ReceiptOp op) {
    switch (op) {
      case TextOp(:final text, :final align, :final bold, :final size):
        final textAlign = switch (align) {
          PosAlign.left => TextAlign.left,
          PosAlign.center => TextAlign.center,
          PosAlign.right => TextAlign.right,
        };
        final fontSize = switch (size) {
          TextSize.normal => 13.0,
          TextSize.doubleWidth => 15.0,
          TextSize.doubleHeight => 16.0,
          TextSize.doubleSize => 18.0,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text(
            text,
            textAlign: textAlign,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black,
            ),
          ),
        );

      case RowOp(:final left, :final right, :final bold):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  left,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.0,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                right,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.0,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );

      case DividerOp(:final character):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Text(
            character * 48,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.0,
              color: Colors.black54,
            ),
          ),
        );

      case FeedOp(:final lines):
        return SizedBox(height: lines * 12.0);

      case CutOp():
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Icon(Icons.content_cut, size: 14.0, color: Colors.black38),
              SizedBox(width: 4.0),
              Expanded(
                child: Divider(
                  color: Colors.black26,
                  thickness: 1.0,
                ),
              ),
            ],
          ),
        );

      case QrOp(:final data):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.white,
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 80.0, color: Colors.black),
                  Text(
                    data,
                    style: const TextStyle(fontSize: 10.0, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );

      case BarcodeOp(:final data):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Column(
              children: [
                Container(
                  height: 40.0,
                  width: 140.0,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Text(
                    '||||||||||||||||||||||||',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 16.0,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  data,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.0),
                ),
              ],
            ),
          ),
        );

      case ImageOp():
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Icon(Icons.image, size: 48.0, color: Colors.black54),
          ),
        );

      case CashDrawerOp():
      case RawBytesOp():
        return const SizedBox.shrink();
    }
  }
}

