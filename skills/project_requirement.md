# Project Requirement: `escpos_link` (v2)

> Status: **Draft v0.2**. Name and package structure (single plugin vs several packages)
> are still open. Default assumption: **single plugin with clean internal layers**.
>
> **v2 changes:** added (1) beginner-friendly developer experience and (2) multi-language
> printing with proper print format.

## 1. Problem statement

Flutter developers who build POS, restaurant, or retail apps must print receipts on
thermal printers. Today they combine 2-3 packages (WiFi, Bluetooth, USB), each with a
different API, poor error messages, and weak support for non-English text.

**Realistic example:** a restaurant in Dhaka has a WiFi kitchen printer, a USB cashier
printer, and waiters with Bluetooth printers. Receipts must show Bangla item names, and
tourists' orders may include Chinese or Japanese names. A junior developer ends up with
three print code paths, garbled Bangla (letters split instead of joined), and cryptic
`PlatformException` errors.

## 2. Goals

1. **One package, one API, three connection types** (WiFi, Bluetooth, USB).
2. **Easy for junior/new developers:** print a first receipt in under 15 minutes, with
   no ESC/POS knowledge.
3. **Any language, printed correctly:** Bangla, Chinese, Japanese, Korean, Arabic, Hindi,
   Thai, and Latin/Cyrillic/Greek, in a proper receipt layout.

```dart
final printer = EscposPrinter.wifi('192.168.1.50');   // or .bluetooth(...) / .usb(...)

final receipt = Receipt()
  ..title('MY RESTAURANT')
  ..row('Burger x2', '12.00')
  ..row('বার্গার x1', '6.00')       // Bangla
  ..row('チキンカレー x1', '9.00')    // Japanese
  ..divider()
  ..total('TOTAL', '27.00')
  ..qr('https://example.com/order/1042')
  ..cut();

final result = await printer.print(receipt);
result.when(
  ok: (_) => showSnack('Printed'),
  error: (e) => showSnack(e.message),  // e.hint tells how to fix it
);
```

## 3. Non-goals (for v1)

- Not a general PDF/laser printer package.
- Not a receipt *design tool* (no drag-and-drop editor).
- No iOS Bluetooth Classic or iOS USB (the OS does not allow it for generic printers).
- No cloud printing.
- No automatic translation. The package prints the text it is given.

## 4. Users

| User | Need | Example |
|---|---|---|
| **Junior/new developer** | Copy-paste quick start, clear errors, no jargon | "I just want to print an order, not learn Bluetooth." |
| Experienced developer | Control over transports, profiles, raw bytes | "I need to send a custom command." |
| Restaurant staff (end user) | Reliable printing, no garbled receipts | "Two orders arrive together; both print fully." |
| Customer | Readable receipt in their language | "My Bangla name is printed correctly." |
| Package maintainer | Testable, modular code | "I can test receipts without a printer." |

## 5. Functional requirements

### 5.1 Receipt building

| ID | Requirement | Example |
|---|---|---|
| FR-1 | Text with alignment (left/center/right) | Shop name centered |
| FR-2 | Bold, underline, double width/height | "TOTAL" bold, double size |
| FR-3 | Two- and three-column rows fitting the paper width | `Burger x2 ........ 12.00` |
| FR-4 | Divider line, feed lines | `--------------------------------` |
| FR-5 | Barcode (CODE128, EAN13) | Order number barcode |
| FR-6 | QR code (size, error correction) | Link to a digital receipt |
| FR-7 | Image printing (logo) | Shop logo, 1-bit converted |
| FR-8 | Paper cut (full/partial) | Cut after each ticket |
| FR-9 | Cash drawer pulse | Open drawer after payment |
| FR-10 | Paper sizes 58 mm and 80 mm via printer profiles | Waiter printer vs cashier printer |
| FR-11 | Widget-to-image printing | Print a styled Flutter widget |
| FR-12 | On-screen **receipt preview** before printing | Developer checks layout with no paper |

### 5.2 Connectivity

| ID | Requirement | Example |
|---|---|---|
| FR-20 | **WiFi/LAN** via TCP (default port 9100) | `192.168.1.50:9100` |
| FR-21 | **Bluetooth Classic (SPP)** on Android | 58 mm printer paired in settings |
| FR-22 | **BLE** on Android and iOS | Newer portable printer |
| FR-23 | **USB** on Android (OTG) | Tablet plugged into a cashier printer |
| FR-24 | Discover printers (paired BT, BLE scan, USB list, optional LAN scan) | "Choose a printer" screen |
| FR-25 | Connect, disconnect, observe connection state | Green/red dot in the UI |
| FR-26 | Printer status (paper out, cover open) when supported | "Paper is out" before printing |

### 5.3 Reliability

| ID | Requirement | Example |
|---|---|---|
| FR-30 | Print **queue**: one job at a time, in order | Two orders do not interleave |
| FR-31 | Retry with backoff on transient failure | WiFi blip, reconnect and resend |
| FR-32 | Chunked writes for Bluetooth/BLE | Packet size follows MTU |
| FR-33 | Typed errors via `Result<T>` with `message` + `hint` | `permissionDenied` explains how to fix it |
| FR-34 | Timeouts on connect and write | Never hang the UI on a dead IP |

## 6. Developer experience (DX) requirements: easy for junior developers

**Success metric:** a developer who has never used ESC/POS prints a Bangla + English
receipt on a real printer in **under 15 minutes**, using only the README.

| ID | Requirement | Realistic example |
|---|---|---|
| DX-1 | **3-line quick start** for each transport | `EscposPrinter.wifi(ip)` then `print(Receipt()..text('Hi')..cut())` |
| DX-2 | **Sensible defaults.** Paper 80 mm, text mode auto, code page auto, timeouts set | Junior never sets a code page |
| DX-3 | **Printer presets** for popular models | `PrinterProfile.epsonTmT20`, `.xprinter58` |
| DX-4 | **Friendly errors**: every error has `message` and `hint` | "Bluetooth permission denied. Add BLUETOOTH_CONNECT to AndroidManifest.xml." |
| DX-5 | **`printTestPage()`**: prints a ruler, QR, and one line per supported language | Junior confirms the setup works before writing a receipt |
| DX-6 | **`EscposLink.doctor()`**: setup checker like `flutter doctor` (permissions, manifest, reachability) | Reports "USB host feature missing in manifest" |
| DX-7 | **Receipt preview widget** to check layout on screen | `ReceiptPreview(receipt)` |
| DX-8 | **Ready-made templates** for common receipts | `Receipt.simple(title:, items:, total:)` |
| DX-9 | **Optional drop-in `PrinterPicker` widget** (scan, choose, save) | One widget replaces a custom "choose printer" screen |
| DX-10 | **Advanced API separated** in `package:escpos_link/advanced.dart` | Raw bytes, custom commands, chunk size |
| DX-11 | **Docs for beginners**: quickstart, cookbook (copy-paste recipes), troubleshooting, glossary | "Printer prints nothing" checklist |
| DX-12 | **Typed, discoverable API**: enums not strings, named parameters, autocomplete-friendly | `Align.center`, not `'center'` |
| DX-13 | **Debug-mode asserts** with plain-language messages | "Paper width is 32 chars; this row needs 40." |
| DX-14 | **Verbose logging switch** | `EscposLink.logLevel = LogLevel.verbose` |
| DX-15 | **Example app** with one recipe per screen (WiFi, Bluetooth, USB, languages, preview) | Copy a screen into your app |

## 7. Multi-language printing requirements

### 7.1 Supported scripts

| ID | Script / language | Sample text | Special difficulty | Default strategy |
|---|---|---|---|---|
| ML-1 | Latin + accents (English, French, Spanish) | `Café déjà vu` | Needs correct code page | Native text |
| ML-2 | Cyrillic, Greek | `Спасибо`, `Ευχαριστώ` | Code page | Native if the profile has it, else image |
| ML-3 | **Bangla** | `ধন্যবাদ`, `ক্ষ`, `স্ত্র` | **Letters join into clusters; vowel signs reorder.** Printers rarely have fonts. | Image (Flutter text engine does the shaping) |
| ML-4 | Hindi (Devanagari) | `धन्यवाद` | Same joining issue | Image |
| ML-5 | **Chinese** (Simplified/Traditional) | `谢谢惠顾` / `謝謝惠顧` | Thousands of glyphs; double width | Image (native only if the profile says the printer has a Chinese font) |
| ML-6 | **Japanese** | `ありがとうございます` | Mixed kana + kanji; glyph shapes differ from Chinese | Image (language tag `ja`) |
| ML-7 | Korean | `감사합니다` | Hangul blocks | Image |
| ML-8 | Arabic, Hebrew | `شكراً` | **Right-to-left**, joined letter forms | Image |
| ML-9 | Thai | `ขอบคุณ` | Stacked vowels and tone marks | Image |
| ML-10 | **Mixed text in one line** | `বার্গার x2 / チキン x1` | Different scripts, different widths | Auto: whole line becomes an image |

### 7.2 "Proper print format" requirements

| ID | Requirement | Realistic example |
|---|---|---|
| ML-20 | **Auto text mode (default):** native text when every character is printable natively, image otherwise, decided per line | `Burger x2` prints as fast text; `বার্গার x2` prints as an image |
| ML-21 | **Correct shaping:** joined Bangla/Hindi/Arabic/Thai forms, no split letters | `ক্ষ` is one joined cluster, never `ক ্ ষ` |
| ML-22 | **Right-to-left** lines align and flow correctly | Arabic item name on the right, price on the left |
| ML-23 | **Pixel-accurate rows:** when a row contains non-native text, the whole row is laid out in pixels, so the price stays right-aligned | `বার্গার x2 ........ 12.00` ends exactly at the right edge |
| ML-24 | **Correct wrapping** by pixel width: break at spaces for Bangla/Latin, between characters for Chinese/Japanese | Long Chinese item name wraps to line 2 without clipping |
| ML-25 | **Double-width awareness** for native CJK text (full-width characters count as 2 columns) | Column math stays right in native mode |
| ML-26 | **Consistent text size and line spacing** across scripts | Bangla and English lines have the same visual size |
| ML-27 | **Language tag** support so Han characters use the right glyph forms | `languageTag: 'ja'` for Japanese, `'zh-Hans'` for Simplified Chinese |
| ML-28 | **Readable 1-bit output:** crisp threshold by default, dithering optional, no clipped edges | Small Bangla marks (`ি`, `ু`) stay visible |
| ML-29 | **Fonts:** use system fonts by default; allow custom fonts; offer an optional font pack | App passes `fontFamily: 'NotoSansBengali'` |
| ML-30 | **Fit to printer width** (58 mm = about 384 dots, 80 mm = about 576 dots, configurable per profile) | No text cut off at the right edge |
| ML-31 | **Image strips:** tall bitmaps are sent in bands to respect the printer's buffer | A 60-line receipt does not overflow a cheap printer |
| ML-32 | **Cache** rendered lines | A fixed shop name is rasterized once |
| ML-33 | **Preview matches print** within reason (same rasterizer, same widths) | Developer trusts the on-screen preview |
| ML-34 | **Native CJK printer fonts as opt-in** via profile, because it depends on the printer model | `PrinterProfile(hasChineseFont: true)` |

## 8. Non-functional requirements

- **Performance:** a 50-line English receipt builds in under 20 ms. Rendering a 30-line
  mixed-language receipt takes under 500 ms on a mid-range phone (measure it). 1-bit conversion runs in an isolate.
- **Bluetooth speed:** image lines are bigger than text. *Example:* an 80 mm line 40 dots
  high is about 2.9 KB, so 30 image lines is about 86 KB. Auto mode keeps English lines
  as text to reduce this. Measure real BLE speed per printer.
- **Size:** core has no heavy dependencies. CJK fonts are **not** bundled by default.
- **Permissions:** declare only what is needed; document how to remove the rest.
- **Testing:** 80%+ coverage on `core/`; golden-bytes tests for commands; golden-image
  tests for text layout with the language fixtures.
- **Compatibility:** Flutter stable, Android `minSdk 21`, iOS 12+.
- **Docs:** every public member has `///` docs with an example.

## 9. Platform support matrix

| Transport | Android | iOS | Desktop | Web |
|---|---|---|---|---|
| WiFi (TCP) | Yes | Yes (needs local-network permission text) | Yes | No |
| Bluetooth Classic | Yes | No | Later | No |
| BLE | Yes | Yes | Later | Later |
| USB | Yes (OTG) | No | Later | Later |

Text rendering (all languages) works wherever Flutter runs. Whether the *device* has a
suitable font differs by platform: iOS and most Android devices include Bengali, Chinese,
and Japanese fonts, but this is not guaranteed on every Android phone. Hence the optional font pack.

## 10. Acceptance criteria (examples)

1. **Given** a WiFi printer, **when** I print the 3-line quick start, **then** one line prints and the paper is cut.
2. **Given** `Receipt()..row('বার্গার x2', '12.00')`, **then** the Bangla letters are joined correctly
   and `12.00` is flush against the right edge on both 58 mm and 80 mm paper.
3. **Given** a Japanese line and a Chinese line using the same characters, **when** I set
   `languageTag: 'ja'` / `'zh-Hans'`, **then** each uses its own language's glyph shapes.
4. **Given** an Arabic line, **then** it is right-to-left and aligned to the right.
5. **Given** a very long Chinese item name, **then** it wraps inside the paper width without clipping.
6. **Given** a mixed line `Burger / বার্গার / バーガー`, **then** it prints as one aligned line.
7. **Given** the printer is off, **then** I get `Result.error` within 5 seconds, with `message` and `hint`, and no crash.
8. **Given** two `print()` calls 100 ms apart, **then** receipt 1 fully prints before receipt 2 starts.
9. **Given** an iOS device, **when** I call `isSupported(Transport.usb)`, **then** it is `false`.
10. **Given** a new developer and only the README, **then** they print the test page in under 15 minutes.
11. **Given** `ReceiptPreview(receipt)`, **then** the on-screen result matches the printed layout in line breaks and alignment.

## 11. Constraints and risks

| Risk | Mitigation |
|---|---|
| Printers differ in code pages and built-in fonts | Printer profiles; conservative `auto` default (image when unsure) |
| Native CJK modes differ per printer model | Opt-in only; verify with the printer manual and a real device |
| System fonts missing on some Android devices | Optional font pack; `printTestPage()` shows the problem |
| Han unification: wrong glyph forms for Chinese vs Japanese | `languageTag` support; fixtures for both |
| Image text is slow over Bluetooth | Auto mode keeps Latin as text; band sending; caching; document trade-offs |
| Cheap printers have small buffers | Send images in bands; configurable band height |
| 1-bit conversion makes small marks vanish | Test with Bangla fixtures; tune threshold; optional dithering |
| Android permissions bloat other apps | Mark features optional; consider splitting packages later |
| No printer in CI | `FakeTransport`, golden-bytes, and golden-image tests |
| API grows too complex for beginners | The 3-line test and `advanced.dart` split |

## 12. Open questions

- [ ] Final package name (`escpos_link`, `thermal_link`, `printbridge`, `posprint_kit`)
- [ ] Single plugin vs federated multi-package
- [ ] Font policy: system fonts only, or ship an optional `escpos_link_fonts` pack (size vs reliability)?
- [ ] Which printer models are tested (e.g. Epson TM-T20, Xprinter XP-58)?
- [ ] Default 1-bit method: plain threshold or dithering?
- [ ] Desktop support in v1?
- [ ] Which languages must be verified on **real** printers before release (Bangla, Chinese, Japanese at minimum)?
