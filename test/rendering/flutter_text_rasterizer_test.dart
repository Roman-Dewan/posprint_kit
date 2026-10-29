import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/advanced.dart';
import '../fixtures/languages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterTextRasterizer Tests (Phase 5 Text Engine)', () {
    late FlutterTextRasterizer rasterizer;

    setUp(() {
      rasterizer = FlutterTextRasterizer(enableCache: true);
    });

    test('renders Bangla text with conjuncts (ক্ষ, স্ত্র) into valid GrayBitmap', () async {
      final gray = await rasterizer.renderText(
        TestLanguages.bangla.complex,
        widthDots: 576,
        style: const TextStyleSpec(fontSize: 24.0),
        languageTag: 'bn',
      );

      expect(gray.width, 576);
      expect(gray.height, greaterThan(20));
      expect(gray.pixels.length, 576 * gray.height);

      // Verify that black pixels exist (text was drawn)
      expect(gray.pixels.any((p) => p < 128), isTrue);
    });

    test('renders Chinese Simplified text into valid GrayBitmap', () async {
      final gray = await rasterizer.renderText(
        TestLanguages.chineseSimplified.complex,
        widthDots: 576,
        style: const TextStyleSpec(fontSize: 24.0),
        languageTag: 'zh-Hans',
      );

      expect(gray.width, 576);
      expect(gray.height, greaterThan(20));
      expect(gray.pixels.any((p) => p < 128), isTrue);
    });

    test('renders Japanese text into valid GrayBitmap', () async {
      final gray = await rasterizer.renderText(
        TestLanguages.japanese.complex,
        widthDots: 576,
        style: const TextStyleSpec(fontSize: 24.0),
        languageTag: 'ja',
      );

      expect(gray.width, 576);
      expect(gray.height, greaterThan(20));
      expect(gray.pixels.any((p) => p < 128), isTrue);
    });

    test('renders Arabic RTL text into valid GrayBitmap', () async {
      final gray = await rasterizer.renderText(
        TestLanguages.arabic.complex,
        widthDots: 576,
        style: const TextStyleSpec(fontSize: 24.0),
        languageTag: 'ar',
      );

      expect(gray.width, 576);
      expect(gray.height, greaterThan(20));
      expect(gray.pixels.any((p) => p < 128), isTrue);
    });

    test('renderRow lays out left text and flushes price to right margin', () async {
      // 80 mm (576 dots)
      final row80 = await rasterizer.renderRow(
        'বার্গার x2',
        '12.00',
        widthDots: 576,
        style: const TextStyleSpec(fontSize: 24.0),
        languageTag: 'bn',
      );

      expect(row80.width, 576);
      expect(row80.height, greaterThan(20));

      // Check that rightmost area has non-white pixels (the price is drawn near the right edge)
      var hasPixelsNearRightEdge = false;
      for (var y = 0; y < row80.height; y++) {
        for (var x = 540; x < 576; x++) {
          if (row80.pixels[y * 576 + x] < 128) {
            hasPixelsNearRightEdge = true;
            break;
          }
        }
      }
      expect(hasPixelsNearRightEdge, isTrue);

      // 58 mm (384 dots)
      final row58 = await rasterizer.renderRow(
        'বার্গার x2',
        '12.00',
        widthDots: 384,
        style: const TextStyleSpec(fontSize: 24.0),
        languageTag: 'bn',
      );

      expect(row58.width, 384);
      expect(row58.height, greaterThan(20));
    });

    test('long line wraps within paper width without error', () async {
      final gray = await rasterizer.renderText(
        TestLanguages.chineseSimplified.longLine,
        widthDots: 384, // narrow 58 mm
        style: const TextStyleSpec(fontSize: 24.0),
        languageTag: 'zh-Hans',
      );

      expect(gray.width, 384);
      // Long line wrapping increases vertical height
      expect(gray.height, greaterThan(40));
    });

    test('cache returns identical bitmap for repeated queries', () async {
      const text = 'MY FIXED SHOP HEADER';
      final gray1 = await rasterizer.renderText(
        text,
        widthDots: 576,
        style: const TextStyleSpec(fontSize: 28.0),
      );

      final gray2 = await rasterizer.renderText(
        text,
        widthDots: 576,
        style: const TextStyleSpec(fontSize: 28.0),
      );

      expect(identical(gray1, gray2), isTrue);
    });

    test('BitmapConverter.toMonoAsync runs thresholding off-thread', () async {
      final gray = await rasterizer.renderText(
        'Test Isolate',
        widthDots: 384,
        style: const TextStyleSpec(fontSize: 24.0),
      );

      final mono = await BitmapConverter.toMonoAsync(gray, threshold: 128);

      expect(mono.width, 384);
      expect(mono.height, gray.height);
      expect(mono.bytesPerLine, 48); // 384 / 8
      expect(mono.data.length, 48 * gray.height);
    });

    test('Mixed language receipt encodes through FakeTransport with FlutterTextRasterizer', () async {
      final fake = FakeTransport();
      final printer = EscposPrinter.custom(
        fake,
        profile: PrinterProfile.generic80,
        rasterizer: rasterizer,
      );

      // Realistic check matching architecture & tasks.md:
      // মাই রেস্টুরেন্ট
      // Burger x2                 12.00
      // বার্গার x1                 6.00
      // チキンカレー x1             9.00
      // 这是一个很长的中文菜名需要换行
      // TOTAL                     27.00
      final receipt = Receipt()
        ..title('মাই রেস্টুরেন্ট', languageTag: 'bn')
        ..divider()
        ..row('Burger x2', '12.00')
        ..row('বার্গার x1', '6.00', languageTag: 'bn')
        ..row('チキンカレー x1', '9.00', languageTag: 'ja')
        ..text('这是一个很长的中文菜名需要换行', languageTag: 'zh-Hans')
        ..divider()
        ..total('TOTAL', '27.00')
        ..cut();

      final result = await printer.print(receipt);
      expect(result.isOk, isTrue);

      final bytes = fake.recordedBytes;
      expect(bytes, isNotEmpty);

      // Verify initialization ESC @ (1B 40)
      expect(bytes.sublist(0, 2), Commands.init);

      // Verify raster graphics command GS v 0 (1D 76 30 00) is present
      // for the non-Latin image lines
      expect(bytes, containsAllInOrder([0x1D, 0x76, 0x30, 0x00]));

      // Verify paper cut at the end
      expect(bytes, containsAllInOrder(Commands.cutFull));

      await printer.close();
    });
  });
}

