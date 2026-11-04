import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/posprint_kit.dart';

void main() {
  group('TsplSize Unit Tests', () {
    test('calculates correct dot dimensions at 203 DPI (8 dots/mm)', () {
      // 20x30 mm
      const s2030 = TsplSize.size20x30;
      expect(s2030.widthMm, 20.0);
      expect(s2030.heightMm, 30.0);
      expect(s2030.dotsPerMm, 8);
      expect(s2030.widthDots, 160);
      expect(s2030.heightDots, 240);
      expect(s2030.gapDots, 16);

      // 30x20 mm
      const s3020 = TsplSize.size30x20;
      expect(s3020.widthDots, 240);
      expect(s3020.heightDots, 160);

      // 40x30 mm
      const s4030 = TsplSize.size40x30;
      expect(s4030.widthDots, 320);
      expect(s4030.heightDots, 240);

      // 60x40 mm
      const s6040 = TsplSize.size60x40;
      expect(s6040.widthDots, 480);
      expect(s6040.heightDots, 320);

      // 50x30 mm
      const s5030 = TsplSize.size50x30;
      expect(s5030.widthDots, 400);
      expect(s5030.heightDots, 240);

      // 80x50 mm
      const s8050 = TsplSize.size80x50;
      expect(s8050.widthDots, 640);
      expect(s8050.heightDots, 400);

      // 100x150 mm (4"x6")
      const s100150 = TsplSize.size100x150;
      expect(s100150.widthDots, 800);
      expect(s100150.heightDots, 1200);
      expect(s100150.gapDots, 24);
    });

    test('calculates correct dot dimensions at 300 DPI (12 dots/mm)', () {
      const s4030 = TsplSize(widthMm: 40, heightMm: 30, dpi: 300);
      expect(s4030.dotsPerMm, 12);
      expect(s4030.widthDots, 480);
      expect(s4030.heightDots, 360);
      expect(s4030.gapDots, 24);
    });

    test('presets list contains all standard sizes', () {
      expect(TsplSize.presets.length, 8);
      expect(TsplSize.presets, contains(TsplSize.size20x30));
      expect(TsplSize.presets, contains(TsplSize.size30x20));
      expect(TsplSize.presets, contains(TsplSize.size40x30));
      expect(TsplSize.presets, contains(TsplSize.size60x40));
    });

    test('equality and hashCode work as expected', () {
      const a = TsplSize(widthMm: 40, heightMm: 30);
      const b = TsplSize(widthMm: 40, heightMm: 30);
      const c = TsplSize(widthMm: 50, heightMm: 30);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('name and toString provide clear descriptions', () {
      expect(TsplSize.size40x30.name, contains('40 × 30 mm'));
      expect(TsplSize.size40x30.toString(), contains('320x240 dots'));
    });
  });
}
