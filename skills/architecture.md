# Architecture: `escpos_link` (v2)

> Companion to `project_requirement.md`. If code and this file disagree, update this
> file in the same change.
>
> **v2 changes:** simple facade for beginners, `Receipt` (what to print) separated from
> the encoder (bytes), a **text engine** for multi-language printing, a rendering layer
> that holds all Flutter-dependent code, friendly errors, preview, and a doctor tool.

## 1. Core ideas

1. **Three independent concerns:** *what* to print (`Receipt`), *how to turn it into bytes*
   (encoder + text engine), and *how to send bytes* (transport).
2. **Simple outside, flexible inside.** Beginners use `EscposPrinter` + `Receipt`.
   Experts use `advanced.dart`.
3. **Text is not bytes.** Printers only know a few code pages. For every other language the
   text is drawn as a small picture by Flutter's text engine (which already knows how to
   shape Bangla, Arabic, Thai, CJK) and printed as an image.

**Example:** `Receipt()..row('Burger x2', '12.00')` becomes plain text bytes (fast).
`Receipt()..row('বার্গার x2', '12.00')` becomes one picture of the row, with the price drawn
flush right, then printed as an image. The app code is identical.

## 2. Layer diagram

```
 App code            (3 lines: EscposPrinter.wifi(..), Receipt(), printer.print(..))
    │
┌───▼────────────────────────────────────────────────────┐
│ EscposPrinter  (facade)  + EscposLink.doctor()         │  Layer 5  simple API
├────────────────────────────────────────────────────────┤
│ PrinterManager (queue, retry, state, chunking)         │  Layer 4
├────────────────────────────────────────────────────────┤
│ Receipt (list of ops)  ──►  ReceiptEncoder  ──► bytes  │  Layer 3  pure Dart
│                                 │                      │
│                          TextEngine (auto decision)    │
│                            ├─ CodePageEncoder (native) │
│                            └─ TextRasterizer ◄──interface (pure Dart)
├────────────────────────────────────────────────────────┤
│ FlutterTextRasterizer (dart:ui)                        │  Layer 2b rendering/
│ ReceiptPreview widget, PrinterPicker widget            │  (Flutter-only)
├────────────────────────────────────────────────────────┤
│ PrinterTransport (abstract)                            │  Layer 2a
├────────────┬──────────────┬────────────────────────────┤
│ Network    │ Bluetooth    │ USB                        │  Layer 1
│ dart:io    │ Kotlin       │ Kotlin                     │
└────────────┴──────────────┴────────────────────────────┘
```

Dependency rule: arrows point down. `core/` never imports `dart:ui` or `package:flutter`.
Only `rendering/` and `ui/` may.

## 3. Folder structure

```
escpos_link/
├── CLAUDE.md  project_requirement.md  architecture.md  skills.md  tasks.md
├── doc/                              # beginner docs
│   ├── quickstart.md                 # 3-line start per transport
│   ├── cookbook.md                   # copy-paste recipes (Bangla, Chinese, QR, logo...)
│   ├── troubleshooting.md            # "prints nothing", "garbled text", "permission denied"
│   └── glossary.md                   # code page, raster, MTU, dithering in plain words
├── lib/
│   ├── escpos_link.dart              # beginner API exports only
│   ├── advanced.dart                 # raw bytes, custom commands, chunk size, profiles
│   └── src/
│       ├── core/                     # NO flutter / dart:ui imports
│       │   ├── receipt.dart          # Receipt: list of ops (text, row, qr, image, cut...)
│       │   ├── ops.dart              # ReceiptOp sealed classes
│       │   ├── receipt_encoder.dart  # ops -> Uint8List (async)
│       │   ├── commands.dart         # byte constants (ESC, GS, FS...)
│       │   ├── text_engine.dart      # native vs image decision, row layout, wrapping
│       │   ├── code_pages.dart       # CodePageEncoder + tables
│       │   ├── text_metrics.dart     # display width of characters (CJK = 2 columns)
│       │   ├── raster.dart           # GrayBitmap, MonoBitmap, threshold/dither, GS v 0 bands
│       │   ├── text_rasterizer.dart  # abstract TextRasterizer (the seam to dart:ui)
│       │   ├── printer_profile.dart  # paper dots, code pages, CJK font flag, presets
│       │   └── result.dart           # Result<T>, PrinterError(message, hint)
│       ├── rendering/                # Flutter-only
│       │   ├── flutter_text_rasterizer.dart
│       │   ├── widget_rasterizer.dart
│       │   └── receipt_preview.dart
│       ├── ui/
│       │   └── printer_picker.dart   # optional drop-in widget
│       ├── transports/
│       │   ├── printer_transport.dart
│       │   ├── network_transport.dart     # NO flutter imports
│       │   ├── bluetooth_transport.dart
│       │   ├── usb_transport.dart
│       │   └── fake_transport.dart
│       ├── discovery/printer_discovery.dart
│       ├── manager/{printer_manager.dart, print_queue.dart}
│       ├── doctor/doctor.dart
│       └── printer.dart              # EscposPrinter facade
├── android/src/main/kotlin/.../{EscposLinkPlugin,BluetoothHandler,UsbHandler}.kt
├── ios/                              # BLE (later)
├── test/
│   ├── fixtures/languages.dart       # sample strings per language
│   ├── core/                         # golden-bytes tests
│   ├── rendering/goldens/            # golden-image tests (PNG)
│   └── manager/ transports/
└── example/                          # one recipe per screen
```

## 4. Key interfaces

### 4.1 Result and friendly errors

```dart
// OLD: enum PrinterError { connectionFailed, connectionLost, timeout, permissionDenied, ... }
// NEW: errors carry a plain-language message and a fix hint, so beginners are not stuck.
class PrinterError {
  const PrinterError(this.code, {required this.message, required this.hint});
  final PrinterErrorCode code;
  final String message;   // what happened
  final String hint;      // how to fix it

  static const permissionDenied = PrinterError(
    PrinterErrorCode.permissionDenied,
    message: 'Bluetooth permission was denied.',
    hint: 'Ask the user again, and on Android 12+ add BLUETOOTH_CONNECT and '
          'BLUETOOTH_SCAN to AndroidManifest.xml.',
  );
}

enum PrinterErrorCode {
  connectionFailed, connectionLost, timeout, permissionDenied,
  unsupportedPlatform, paperOut, coverOpen, fontMissing, renderFailed, unknown,
}

sealed class Result<T> {
  const Result();
  const factory Result.ok(T value) = Ok<T>;
  const factory Result.error(PrinterError error) = Err<T>;

  // Beginner helper so nobody needs to learn pattern matching first.
  R when<R>({required R Function(T) ok, required R Function(PrinterError) error});
}
```

### 4.2 Receipt (what to print): synchronous, beginner friendly

```dart
class Receipt {
  // OLD: ReceiptBuilder(PaperSize.mm80)  // required paper size and returned bytes directly
  // NEW: Receipt() has no paper size (the printer profile knows it) and only records
  //      operations; bytes are produced later by the encoder, because drawing
  //      non-Latin text is asynchronous.
  Receipt();

  Receipt text(String s, {Align align = Align.left, bool bold = false,
      TextSize size = TextSize.normal, TextMode mode = TextMode.auto,
      String? languageTag /* 'bn', 'ja', 'zh-Hans', 'ar' */});
  Receipt title(String s);                       // centered, bold, large
  Receipt row(String left, String right);        // price flush right, any language
  Receipt divider();
  Receipt total(String label, String amount);
  Receipt qr(String data, {int size = 6});
  Receipt barcode(String data, {BarcodeType type = BarcodeType.code128});
  Receipt image(RasterSource logo);
  Receipt feed([int lines = 1]);
  Receipt cut({bool partial = false});
  Receipt drawer();

  factory Receipt.simple({required String title, required List<(String, String)> items,
      required String total});
}

enum TextMode { auto, native, image }   // auto = default, decided per line
```

### 4.3 Encoder, text engine, rasterizer

```dart
class ReceiptEncoder {
  ReceiptEncoder(this.profile, this.rasterizer);
  final PrinterProfile profile;
  final TextRasterizer rasterizer;   // FlutterTextRasterizer in apps, FakeRasterizer in tests

  /// Turns a receipt into printer bytes. Prepends ESC @ (init) unless [init] is false.
  Future<Result<Uint8List>> encode(Receipt receipt, {bool init = true});
}

/// The only seam between pure Dart and Flutter's text engine.
abstract class TextRasterizer {
  Future<GrayBitmap> renderText(String text, {
    required int widthDots, required TextStyleSpec style,
    Align align = Align.left, String? languageTag});

  /// Left text and right text laid out on ONE line, price flush right.
  Future<GrayBitmap> renderRow(String left, String right, {
    required int widthDots, required TextStyleSpec style, String? languageTag});
}

class PrinterProfile {
  const PrinterProfile({required this.dotsWidth, this.codePages = const [CodePage.cp437],
      this.hasChineseFont = false, this.hasJapaneseFont = false,
      this.maxBandRows = 128, this.supportsPartialCut = true});
  final int dotsWidth;           // 58 mm ~ 384, 80 mm ~ 576 (some are 512)
  // ...
  static const generic58 = PrinterProfile(dotsWidth: 384);
  static const generic80 = PrinterProfile(dotsWidth: 576);   // default
}
```

### 4.4 Transport

```dart
abstract class PrinterTransport {
  Future<Result<void>> connect();
  Future<Result<void>> write(Uint8List bytes);
  Future<Result<Uint8List?>> read({Duration timeout});
  Future<void> disconnect();
  Stream<ConnectionState> get state;
  int get maxChunkSize;          // network 64 KB, BLE MTU-3 ...
}
```

### 4.5 Beginner facade

```dart
class EscposPrinter {
  EscposPrinter.wifi(String host, {int port = 9100, PrinterProfile profile = PrinterProfile.generic80});
  EscposPrinter.bluetooth(String address, {PrinterProfile profile = PrinterProfile.generic58});
  EscposPrinter.usb({required int vendorId, required int productId,
      PrinterProfile profile = PrinterProfile.generic80});

  Future<Result<void>> print(Receipt receipt);
  Future<Result<void>> printTestPage();   // ruler + QR + one line per language
  Future<void> close();
}

class EscposLink {
  static Future<DoctorReport> doctor();   // checks permissions, manifest, reachability
  static bool isSupported(Transport t);
  static LogLevel logLevel = LogLevel.warning;
}
```

## 5. Text engine: how any language prints correctly

### 5.1 The auto decision (per line)

```
for each text op:
  if mode == native            -> encode with code page (error if not encodable)
  if mode == image             -> rasterize
  if mode == auto:
        every character encodable in the profile's code pages
        (or profile says printer has a CJK font for this script)?
            yes -> native text   (fast, small)
            no  -> rasterize the WHOLE line  (never mix half native, half image)
```

| Line | Decision | Why |
|---|---|---|
| `Burger x2 ... 12.00` | native | all ASCII |
| `Café` | native if the profile has CP858/CP1252, else image | `é` needs a code page |
| `বার্গার x2 ... 12.00` | image | Bangla not in any printer code page |
| `谢谢惠顾` | image (native only if `hasChineseFont`) | model dependent |
| `شكراً` | image | needs shaping + right-to-left |
| `Burger / বার্গার / バーガー` | one image row | mixed scripts, keep alignment |

### 5.2 Layout in pixels (why prices stay aligned)

Character-count padding (`'Burger'.padRight(30)`) fails for non-Latin text, because widths
differ per character and Bangla clusters are not 1 character wide. So for image rows:

```
widthDots = profile.dotsWidth                      // e.g. 576
right text  = measure(right)                       // pixels
left box    = widthDots - rightWidth - gap
wrap left   = break by pixel width into the left box
draw        = left text at x=0, right text at x = widthDots - rightWidth
```

**Example (80 mm, 576 dots):** `বার্গার x2` on the left, `12.00` on the right. The price is
drawn so its right edge is at dot 576, whatever the Bangla width is.

### 5.3 Wrapping and direction

- Bangla, Latin, Cyrillic, Hindi: break at spaces.
- Chinese, Japanese: may break between any two characters (but not before closing
  punctuation such as `。` and `、`; let Flutter's line breaker handle this).
- Thai: needs dictionary-based breaking; rely on Flutter/ICU, do not write your own.
- Arabic/Hebrew: paragraph direction right-to-left; alignment `start` means right.

### 5.4 Shaping and glyph choice: delegate to Flutter

`FlutterTextRasterizer` uses `dart:ui` `ParagraphBuilder` (same engine as `Text`), so
Bangla conjuncts, Arabic joining, and Thai stacking come out right. Rules:

- Pass `languageTag` as the paragraph `locale` so Han characters use the right glyph forms
  (some characters, such as 直 and 骨, look different in Chinese and Japanese fonts).
- Use `fontFamilyFallback` listing the script fonts (e.g. Noto Sans Bengali, Noto Sans CJK).
- Render **black on white** at the exact `widthDots`, so no resizing blurs the glyphs.

### 5.5 From picture to printer bytes

```
FlutterTextRasterizer  -> GrayBitmap (0..255, width = widthDots)
BitmapOps.toMono(...)  -> MonoBitmap (1 bit/pixel)   [runs in an isolate via compute]
RasterEncoder.bands()  -> GS v 0 commands in bands of profile.maxBandRows rows
```

- **Threshold** by default (crisp); **dithering** optional (photos/logos).
- Small marks (Bangla `ি`, `ু`, Japanese dakuten `゛`) must survive conversion. Test with fixtures.
- **Bands:** cheap printers have small buffers, so send tall images as several `GS v 0` blocks.
- **Cache** `(text, style, width, languageTag)` to bitmap so repeated lines are drawn once.

**Size estimate:** 80 mm = 576 dots = 72 bytes per pixel row. A 40-pixel-high line is about
2.9 KB, so 30 image lines is about 86 KB. That is fine over WiFi/USB, slow over Bluetooth;
this is why `auto` keeps English lines as text.

### 5.6 Fonts

| Option | Pros | Cons |
|---|---|---|
| **System fonts (default)** | No app size increase | Not guaranteed on every Android device |
| App-supplied fonts | Full control | Developer must bundle and register |
| Optional `escpos_link_fonts` pack | Reliable, consistent | Adds MBs (CJK especially) |

`printTestPage()` and `doctor()` help a junior spot a missing font (boxes instead of letters).

### 5.7 Native CJK (opt-in)

Some printers have built-in Chinese/Japanese/Korean fonts that use a different mode (for example
the `FS &` / `FS .` commands with GBK or Shift-JIS encoding on many models). This is **model
dependent**, so it is off by default. Enable it only through `PrinterProfile(hasChineseFont: true)`
after checking the printer manual and a real device. Native CJK text is double width, so
`TextMetrics` counts each full-width character as 2 columns.

## 6. Data flow example

Waiter taps "Print order #1042" (Bluetooth, 58 mm, receipt has a Bangla line):

```
1. Receipt()..title(..)..row('বার্গার x2','12.00')..cut()   -> list of ops
2. printer.print(receipt)           -> PrinterManager enqueues
3. Queue picks job                  -> ReceiptEncoder.encode(receipt)
4.   title (ASCII)                  -> native bytes
5.   Bangla row                     -> FlutterTextRasterizer.renderRow -> GrayBitmap
6.                                  -> toMono (isolate) -> GS v 0 bands
7.   cut                            -> GS V ...
8. transport.connect() if needed
9. bytes split by maxChunkSize      -> write chunks (small delay on BLE)
10. Result.ok / Result.error(message, hint) -> app shows it
```

## 7. Platform channel contract (Android)

Channel `escpos_link/methods` (EventChannel `escpos_link/events`)

| Method | Args | Returns |
|---|---|---|
| `bt.listPaired` | none | `List<{name, address}>` |
| `bt.connect` | `address` | `bool` |
| `bt.write` | `bytes` | `bool` |
| `bt.disconnect` | none | `void` |
| `usb.list` | none | `List<{vendorId, productId, name}>` |
| `usb.requestPermission` | `vendorId, productId` | `bool` |
| `usb.connect` / `usb.write` | ids / `bytes` | `bool` |
| `doctor.check` | none | `Map<String, bool>` (permissions, usb host feature) |

Rules: Kotlin never throws to Dart; it returns error codes mapped to `PrinterError` with a
message and hint. I/O runs on a background thread.

## 8. Permissions

| Transport | Android | iOS |
|---|---|---|
| WiFi | `INTERNET`, `ACCESS_NETWORK_STATE` | `NSLocalNetworkUsageDescription` |
| Bluetooth (API 31+) | `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN` | `NSBluetoothAlwaysUsageDescription` |
| Bluetooth (API 30 and below) | `BLUETOOTH`, `BLUETOOTH_ADMIN`, location (scan) | n/a |
| USB | `uses-feature android.hardware.usb.host` (`required="false"`) | not supported |

## 9. Testing strategy

| Level | What | Example |
|---|---|---|
| Golden bytes | Exact bytes per command | bold on == `[0x1B,0x45,0x01]` |
| **Golden image** | PNG of rendered rows, per language fixture | Bangla row matches the approved PNG |
| Unit | Auto decision, wrapping, width math | `Café` native with CP858, image with CP437 |
| Unit | Queue order, retry | Job 2 starts after job 1 |
| Integration | `NetworkTransport` vs local `ServerSocket` | Server receives exact bytes |
| Manual device | Real printers: Latin, Bangla, Chinese, Japanese | Checklist in `tasks.md` |

`test/fixtures/languages.dart` is the single source of sample strings (Bangla `ধন্যবাদ`, `ক্ষ`,
Chinese `谢谢惠顾`, Japanese `ありがとうございます`, Korean `감사합니다`, Arabic `شكراً`, Hindi
`धन्यवाद`, Thai `ขอบคุณ`). `FakeRasterizer` returns deterministic bitmaps for byte-level tests.

## 10. Decision log (ADRs)

| # | Decision | Reason | Status |
|---|---|---|---|
| 1 | Separate receipt/encoding from transport | New connections never touch receipt logic | Accepted |
| 2 | `Result<T>` instead of exceptions | Simple app code; no uncaught platform errors | Accepted |
| 3 | Core has no Flutter imports | Can split into a pure Dart package later | Accepted |
| 4 | Single plugin with layered folders for now | Faster start; permission bloat is a known trade-off | **Revisit before publishing** |
| 5 | Non-Latin text printed as images | Printers lack fonts and shaping for Bangla etc. | Accepted |
| 6 | `Receipt` records ops; encoding is async | Drawing text is async; keeps the builder simple | Accepted |
| 7 | `TextRasterizer` interface in core, `dart:ui` impl in `rendering/` | Keeps rule 3 true while using Flutter's shaping | Accepted |
| 8 | `TextMode.auto` default, decided per line | Fast English, correct everything else | Accepted |
| 9 | System fonts default, optional font pack | Small app size vs reliability | **Open** |
| 10 | Errors carry `message` + `hint` | Juniors can fix problems without searching | Accepted |
| 11 | Beginner API in `escpos_link.dart`, rest in `advanced.dart` | Keeps the common path to 3 lines | Accepted |
| 12 | Native CJK printer fonts opt-in only | Model-dependent behaviour | Accepted |

## 11. Future split (if needed)

```
escpos_link_core       <- lib/src/core + printer_transport.dart
escpos_link_render     <- lib/src/rendering (Flutter text engine)
escpos_link_network    <- network_transport.dart
escpos_link_bluetooth  <- bluetooth_transport.dart + Kotlin
escpos_link_usb        <- usb_transport.dart + Kotlin
escpos_link_fonts      <- optional font pack
escpos_link            <- umbrella that re-exports all
```

The split is cheap only if rule 1 in `CLAUDE.md` is respected.
