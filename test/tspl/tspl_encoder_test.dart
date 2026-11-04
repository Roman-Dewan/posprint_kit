import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/posprint_kit.dart';
import 'package:posprint_kit/src/core/raster.dart';

void main() {
  group('TsplEncoder Unit Tests', () {
    const encoder = TsplEncoder();

    test('encodes standard label header commands', () async {
      final label = TsplLabel(size: TsplSize.size40x30)
        ..reference(5, 10)
        ..setSpeed(4)
        ..setDensity(10);

      final bytes = await encoder.encode(label);
      final text = utf8.decode(bytes);

      expect(text, contains('SIZE 40 mm, 30 mm\r\n'));
      expect(text, contains('GAP 2 mm, 0 mm\r\n'));
      expect(text, contains('DIRECTION 1\r\n'));
      expect(text, contains('REFERENCE 5, 10\r\n'));
      expect(text, contains('SPEED 4\r\n'));
      expect(text, contains('DENSITY 10\r\n'));
      expect(text, contains('CLS\r\n'));
      expect(text, contains('PRINT 1, 1\r\n'));
    });

    test('encodes custom gap override and 180° reverse direction', () async {
      final label = TsplLabel(size: TsplSize.size60x40)
        ..gap(3.5)
        ..setDirection(TsplDirection.reverse)
        ..print(copies: 2);

      final bytes = await encoder.encode(label);
      final text = utf8.decode(bytes);

      expect(text, contains('SIZE 60 mm, 40 mm\r\n'));
      expect(text, contains('GAP 3.5 mm, 0 mm\r\n'));
      expect(text, contains('DIRECTION 0\r\n'));
      expect(text, contains('PRINT 2, 1\r\n'));
    });

    test('encodes TEXT, BARCODE, QRCODE, BOX, BAR, and REVERSE correctly', () async {
      final label = TsplLabel(size: TsplSize.size40x30)
        ..text('ORGANIC HONEY', horizontal: 20, vertical: 20, font: TsplFont.font3)
        ..barcode('890123456789', horizontal: 20, vertical: 80, height: 45)
        ..qr('https://honey.example.com', horizontal: 220, vertical: 80, size: 4)
        ..box(horizontal: 5, vertical: 5, endHorizontal: 315, endVertical: 235, thickness: 2)
        ..bar(horizontal: 10, vertical: 50, width: 300, height: 2)
        ..reverse(horizontal: 10, vertical: 160, width: 60, height: 25)
        ..cut();

      final bytes = await encoder.encode(label);
      final text = utf8.decode(bytes);

      expect(text, contains('TEXT 20, 20, "3", 0, 1, 1, "ORGANIC HONEY"\r\n'));
      expect(text, contains('BARCODE 20, 80, "128", 45, 1, 0, 2, 2, "890123456789"\r\n'));
      expect(text, contains('QRCODE 220, 80, M, 4, A, 0, M2, S7, "https://honey.example.com"\r\n'));
      expect(text, contains('BOX 5, 5, 315, 235, 2\r\n'));
      expect(text, contains('BAR 10, 50, 300, 2\r\n'));
      expect(text, contains('REVERSE 10, 160, 60, 25\r\n'));
      expect(text, contains('CUT\r\n'));
      expect(text, contains('PRINT 1, 1\r\n'));
    });

    test('encodes millimeter convenience builders accurately into printer dots', () async {
      final label = TsplLabel(size: TsplSize.size40x30)
        ..textMm('FRESH', horizontal: 2.5, vertical: 2.5)
        ..barcodeMm('12345', horizontal: 2.5, vertical: 10.0, height: 5.0)
        ..qrMm('https://example.com', horizontal: 20.0, vertical: 10.0, size: 3)
        ..boxMm(horizontal: 1.0, vertical: 1.0, endHorizontal: 39.0, endVertical: 29.0)
        ..lineMm(horizontal: 2.0, vertical: 6.0, width: 36.0);

      final bytes = await encoder.encode(label);
      final text = utf8.decode(bytes);

      // 2.5 mm * 8 dots/mm = 20 dots; 10 mm * 8 = 80 dots; 5 mm * 8 = 40 dots
      expect(text, contains('TEXT 20, 20, "3", 0, 1, 1, "FRESH"\r\n'));
      expect(text, contains('BARCODE 20, 80, "128", 40, 1, 0, 2, 2, "12345"\r\n'));
      expect(text, contains('QRCODE 160, 80, M, 3, A, 0, M2, S7, "https://example.com"\r\n'));
      expect(text, contains('BOX 8, 8, 312, 232, 2\r\n'));
      expect(text, contains('BAR 16, 48, 288, 2\r\n'));
    });

    test('encodes BITMAP binary data according to TSPL specification (inverted polarity)', () async {
      // Create a small 16x2 monochrome bitmap (2 bytes per line, 4 bytes total)
      final rawData = Uint8List.fromList([0xAA, 0x55, 0xFF, 0x00]);
      final bitmap = MonoBitmap(
        width: 16,
        height: 2,
        bytesPerLine: 2,
        data: rawData,
      );

      final label = TsplLabel(size: TsplSize.size30x20)
        ..image(bitmap, horizontal: 10, vertical: 20);

      final bytes = await encoder.encode(label);

      // Verify command header prefix
      final prefix = utf8.encode('BITMAP 10, 20, 2, 2, 0,');
      final prefixIndex = _indexOfSublist(bytes, prefix);
      expect(prefixIndex, isNonNegative, reason: 'BITMAP command header must exist in output bytes');

      // Verify inverted binary data (0 = black, 1 = white) immediately follows the comma
      final dataStart = prefixIndex + prefix.length;
      final payload = bytes.sublist(dataStart, dataStart + rawData.length);
      final expectedPayload = Uint8List.fromList(rawData.map((b) => b ^ 0xFF).toList());
      expect(payload, equals(expectedPayload));

      // Verify trailing \r\n
      expect(bytes[dataStart + rawData.length], 0x0D);
      expect(bytes[dataStart + rawData.length + 1], 0x0A);
    });
  });
}

int _indexOfSublist(Uint8List source, List<int> pattern) {
  outer:
  for (var i = 0; i <= source.length - pattern.length; i++) {
    for (var j = 0; j < pattern.length; j++) {
      if (source[i + j] != pattern[j]) continue outer;
    }
    return i;
  }
  return -1;
}

