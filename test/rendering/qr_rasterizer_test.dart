import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/src/core/ops.dart';
import 'package:posprint_kit/src/rendering/qr_rasterizer.dart';

void main() {
  group('QrRasterizer Tests', () {
    test('renders valid MonoBitmap with correct dimensions for 80mm paper', () {
      final mono = QrRasterizer.renderQr(
        data: 'https://github.com/roman-dewan/posprint_kit',
        widthDots: 576,
        moduleSize: 6,
        align: PosAlign.center,
      );

      expect(mono.width, 576);
      expect(mono.bytesPerLine, 72); // 576 / 8 = 72
      expect(mono.height, greaterThan(100));
      expect(mono.data.any((b) => b != 0), isTrue); // Contains printed black pixels

      final escPosBytes = mono.toEscPosBytes();
      // ESC/POS GS v 0 prefix: 1D 76 30 00
      expect(escPosBytes[0], 0x1D);
      expect(escPosBytes[1], 0x76);
      expect(escPosBytes[2], 0x30);
      expect(escPosBytes[3], 0x00);
    });

    test('renders valid MonoBitmap for 58mm paper and clamps oversized moduleSize', () {
      final mono = QrRasterizer.renderQr(
        data: 'https://github.com/roman-dewan/posprint_kit',
        widthDots: 384,
        moduleSize: 16, // Requested size too large for 384 dots, will auto-clamp
        align: PosAlign.center,
      );

      expect(mono.width, 384);
      expect(mono.bytesPerLine, 48); // 384 / 8 = 48
      expect(mono.height, lessThanOrEqualTo(384));
    });

    test('respects left and right alignment', () {
      final monoLeft = QrRasterizer.renderQr(
        data: 'TEST',
        widthDots: 576,
        moduleSize: 4,
        align: PosAlign.left,
      );

      final monoRight = QrRasterizer.renderQr(
        data: 'TEST',
        widthDots: 576,
        moduleSize: 4,
        align: PosAlign.right,
      );

      // In monoLeft, dark pixel bytes are in the left half of each 72-byte line (col < 36)
      // In monoRight, dark pixel bytes are in the right half of each 72-byte line (col >= 36)
      final leftCols = <int>[];
      final rightCols = <int>[];
      for (var i = 0; i < monoLeft.data.length; i++) {
        if (monoLeft.data[i] != 0) leftCols.add(i % 72);
        if (monoRight.data[i] != 0) rightCols.add(i % 72);
      }

      expect(leftCols, isNotEmpty);
      expect(rightCols, isNotEmpty);
      expect(leftCols.every((col) => col < 36), isTrue);
      expect(rightCols.every((col) => col >= 36), isTrue);
    });
  });
}
