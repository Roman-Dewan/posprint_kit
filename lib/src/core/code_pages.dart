import 'dart:typed_data';

/// Common ESC/POS character code pages.
enum CodePage {
  /// Standard / PC437 (USA, Standard Europe). Typically selected with `ESC t 0`.
  cp437(0, 'CP437'),

  /// PC850 (Multilingual Latin I). Selected with `ESC t 2`.
  cp850(2, 'CP850'),

  /// PC858 (Multilingual Latin I with Euro symbol). Selected with `ESC t 19`.
  cp858(19, 'CP858'),

  /// Windows-1252 (Latin 1). Typically selected with `ESC t 16`.
  cp1252(16, 'CP1252');

  const CodePage(this.commandNumber, this.name);

  /// The parameter [n] sent with `ESC t n`.
  final int commandNumber;

  /// Human-readable code page name.
  final String name;
}

/// Encoders and character translation tables for ESC/POS native code pages.
class CodePageEncoder {
  CodePageEncoder(this.codePage);

  final CodePage codePage;

  /// Returns `true` if every character in [text] can be natively encoded by this code page.
  bool canEncode(String text) {
    for (final rune in text.runes) {
      if (rune == 0x0A || rune == 0x0D || rune == 0x09) {
        continue;
      }
      if (rune >= 0x20 && rune <= 0x7E) {
        continue;
      }
      if (_encodeRune(rune) == null) {
        return false;
      }
    }
    return true;
  }

  /// Encodes [text] into bytes using this code page.
  /// Throws [FormatException] if any character is unencodable.
  Uint8List encode(String text) {
    final runes = text.runes;
    final bytes = Uint8List(runes.length);
    var i = 0;
    for (final rune in runes) {
      if (rune == 0x0A || rune == 0x0D || rune == 0x09) {
        bytes[i++] = rune;
      } else if (rune >= 0x20 && rune <= 0x7E) {
        bytes[i++] = rune;
      } else {
        final byte = _encodeRune(rune);
        if (byte == null) {
          throw FormatException(
            'Character "${String.fromCharCode(rune)}" (U+${rune.toRadixString(16).toUpperCase()}) '
            'cannot be encoded in ${codePage.name}.',
          );
        }
        bytes[i++] = byte;
      }
    }
    return bytes;
  }

  int? _encodeRune(int rune) {
    switch (codePage) {
      case CodePage.cp437:
        return _unicodeToCp437[rune];
      case CodePage.cp850:
        return _unicodeToCp850[rune];
      case CodePage.cp858:
        return _unicodeToCp858[rune];
      case CodePage.cp1252:
        return _unicodeToCp1252[rune];
    }
  }

  // Common accented character maps
  static final Map<int, int> _unicodeToCp437 = {
    0x00C7: 0x80, // Ç
    0x00FC: 0x81, // ü
    0x00E9: 0x82, // é
    0x00E2: 0x83, // â
    0x00E4: 0x84, // ä
    0x00E0: 0x85, // à
    0x00E5: 0x86, // å
    0x00E7: 0x87, // ç
    0x00EA: 0x88, // ê
    0x00EB: 0x89, // ë
    0x00E8: 0x8A, // è
    0x00EF: 0x8B, // ï
    0x00EE: 0x8C, // î
    0x00EC: 0x8D, // ì
    0x00C4: 0x8E, // Ä
    0x00C5: 0x8F, // Å
    0x00C9: 0x90, // É
    0x00E6: 0x91, // æ
    0x00C6: 0x92, // Æ
    0x00F4: 0x93, // ô
    0x00F6: 0x94, // ö
    0x00F2: 0x95, // ò
    0x00FB: 0x96, // û
    0x00F9: 0x97, // ù
    0x00FF: 0x98, // ÿ
    0x00D6: 0x99, // Ö
    0x00DC: 0x9A, // Ü
    0x00A2: 0x9B, // ¢
    0x00A3: 0x9C, // £
    0x00A5: 0x9D, // ¥
    0x20A7: 0x9E, // ₧
    0x0192: 0x9F, // ƒ
    0x00E1: 0xA0, // á
    0x00ED: 0xA1, // í
    0x00F3: 0xA2, // ó
    0x00FA: 0xA3, // ú
    0x00F1: 0xA4, // ñ
    0x00D1: 0xA5, // Ñ
    0x00AA: 0xA6, // ª
    0x00BA: 0xA7, // º
    0x00BF: 0xA8, // ¿
    0x00AC: 0xAA, // ¬
    0x00BD: 0xAB, // ½
    0x00BC: 0xAC, // ¼
    0x00A1: 0xAD, // ¡
    0x00AB: 0xAE, // «
    0x00BB: 0xAF, // »
    0x00DF: 0xE1, // ß
    0x00B0: 0xF8, // °
    0x00B7: 0xFA, // ·
  };

  static final Map<int, int> _unicodeToCp858 = {
    ..._unicodeToCp437,
    0x20AC: 0xD5, // € Euro symbol in CP858
    0x00E1: 0xA0, // á
    0x00ED: 0xA1, // í
    0x00F3: 0xA2, // ó
    0x00FA: 0xA3, // ú
    0x00F1: 0xA4, // ñ
    0x00D1: 0xA5, // Ñ
  };

  static final Map<int, int> _unicodeToCp850 = {
    ..._unicodeToCp437,
    0x00F5: 0xE4, // õ
    0x00D5: 0xE5, // Õ
  };

  static final Map<int, int> _unicodeToCp1252 = {
    0x20AC: 0x80, // €
    0x201A: 0x82, // ‚
    0x0192: 0x83, // ƒ
    0x201E: 0x84, // „
    0x2026: 0x85, // …
    0x2020: 0x86, // †
    0x2021: 0x87, // ‡
    0x02C6: 0x88, // ˆ
    0x2030: 0x89, // ‰
    0x0160: 0x8A, // Š
    0x2039: 0x8B, // ‹
    0x0152: 0x8C, // Œ
    0x017D: 0x8E, // Ž
    0x2018: 0x91, // ‘
    0x2019: 0x92, // ’
    0x201C: 0x93, // “
    0x201D: 0x94, // ”
    0x2022: 0x95, // •
    0x2013: 0x96, // –
    0x2014: 0x97, // —
    0x02DC: 0x98, // ˜
    0x2122: 0x99, // ™
    0x0161: 0x9A, // š
    0x203A: 0x9B, // ›
    0x0153: 0x9C, // œ
    0x017E: 0x9E, // ž
    0x0178: 0x9F, // Ÿ
    // ISO-8859-1 range (0xA0..0xFF) maps directly in CP1252
    for (var r = 0xA0; r <= 0xFF; r++) r: r,
  };
}

