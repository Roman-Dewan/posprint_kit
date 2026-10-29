import 'package:flutter_test/flutter_test.dart';
import 'package:posprint_kit/posprint_kit.dart';

void main() {
  group('EscposLink.doctor Diagnostics (T-902)', () {
    test('doctor checks report status and outputs clean diagnostics string', () async {
      final report = await EscposLink.doctor();

      expect(report.checks, isNotEmpty);
      expect(report.checks.any((c) => c.name.contains('Operating System')), isTrue);
      expect(report.checks.any((c) => c.name.contains('WiFi')), isTrue);

      final str = report.toString();
      expect(str, contains('=== posprint_kit / escpos_link Doctor ==='));
      expect(str, contains('✓'));
    });
  });
}

