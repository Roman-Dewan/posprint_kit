import 'package:flutter_test/flutter_test.dart';

import 'languages.dart';

void main() {
  group('TestLanguages fixtures', () {
    test('contains all expected languages with non-empty samples', () {
      expect(TestLanguages.all.length, greaterThanOrEqualTo(17));
      for (final fixture in TestLanguages.all) {
        expect(fixture.name, isNotEmpty);
        expect(fixture.code, isNotEmpty);
        expect(fixture.simple, isNotEmpty);
        expect(fixture.complex, isNotEmpty);
        expect(fixture.longLine, isNotEmpty);
      }
    });

    test('Bangla fixture contains expected conjuncts', () {
      expect(TestLanguages.bangla.simple, 'ধন্যবাদ');
      expect(TestLanguages.bangla.complex, contains('ক্ষুদ্র'));
      expect(TestLanguages.bangla.complex, contains('স্ত্রীর'));
    });

    test('Guaranteed Indian scripts (Tamil & Telugu) contain expected ligatures', () {
      expect(TestLanguages.tamil.simple, 'நன்றி');
      expect(TestLanguages.tamil.complex, contains('தோசை'));
      expect(TestLanguages.telugu.simple, 'ధన్యవాదాలు');
      expect(TestLanguages.telugu.complex, contains('దోస'));
    });

    test('European guaranteed scripts (German, Portuguese, Turkish) contain accents', () {
      expect(TestLanguages.german.simple, contains('Dankeschön'));
      expect(TestLanguages.portuguese.complex, contains('Pão de queijo'));
      expect(TestLanguages.turkish.complex, contains('İskender'));
    });

    test('Arabic fixture is marked RTL', () {
      expect(TestLanguages.arabic.isRtl, isTrue);
    });
  });
}

