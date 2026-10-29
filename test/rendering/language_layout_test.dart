import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/advanced.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-language Layout & Glyph Tests (T-512, T-513)', () {
    late FlutterTextRasterizer rasterizer;

    setUp(() {
      rasterizer = FlutterTextRasterizer();
    });

    test('T-512 Han unification: renders with zh-Hans and ja locales without crashing', () async {
      // Characters that vary under Han unification: 直, 骨
      const hanText = '直骨';

      final zhBitmap = await rasterizer.renderText(
        hanText,
        widthDots: 384,
        style: const TextStyleSpec(fontSize: 28.0),
        languageTag: 'zh-Hans',
      );

      final jaBitmap = await rasterizer.renderText(
        hanText,
        widthDots: 384,
        style: const TextStyleSpec(fontSize: 28.0),
        languageTag: 'ja',
      );

      expect(zhBitmap.width, 384);
      expect(jaBitmap.width, 384);
      expect(zhBitmap.pixels.any((p) => p < 128), isTrue);
      expect(jaBitmap.pixels.any((p) => p < 128), isTrue);
    });

    test('T-513 Bangla conjuncts and vowel marks survive 1-bit conversion', () async {
      // Test words with small dependent vowel signs and conjunct clusters:
      // কি, কু, ধন্যবাদ, ক্ষুদ্র, স্ত্রী
      const banglaText = 'কি কু ধন্যবাদ ক্ষুদ্র স্ত্রী';

      final gray = await rasterizer.renderText(
        banglaText,
        widthDots: 576,
        style: const TextStyleSpec(fontSize: 26.0),
        languageTag: 'bn',
      );

      // Convert to 1-bit monochrome
      final mono = gray.toMono(threshold: 128);

      // Verify that black bits are generated in the mono data
      var blackDotsCount = 0;
      for (final byte in mono.data) {
        for (var b = 0; b < 8; b++) {
          if ((byte & (1 << b)) != 0) {
            blackDotsCount++;
          }
        }
      }

      // Must have substantial black dots for text and marks
      expect(blackDotsCount, greaterThan(100));
    });
  });
}

