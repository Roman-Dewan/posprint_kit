# skills.md: Agent Playbooks (v2)

> Step-by-step recipes for the tasks you will do most often. Follow the matching
> playbook instead of improvising. Each has a realistic example.
>
> **v2 changes:** tests now use the async encoder; Skill 8 rewritten for multi-language text;
> new Skills 9-13 for languages, beginner-friendly API design, friendly errors, golden images,
> and beginner docs.

Helper used in tests: `encodeForTest(receipt)` runs `ReceiptEncoder(PrinterProfile.generic80,
FakeRasterizer()).encode(receipt, init: false)` and returns the bytes.

---

## Skill 1: Add a new ESC/POS command to `Receipt`

**When:** a feature needs bytes we don't generate yet (underline, cash drawer, barcode...).

**Steps**
1. Look up the exact byte sequence in the ESC/POS command reference. Do not guess.
2. Add constant(s) to `core/commands.dart`.
3. Add a new `ReceiptOp` in `core/ops.dart` and a fluent method on `Receipt` that returns `this`.
4. Handle the op in `ReceiptEncoder`.
5. Write a **golden-bytes test first**.
6. Add a `///` doc comment with a usage example, then update `CHANGELOG.md` and `tasks.md`.

**Realistic example: underline** (`ESC - n` = `1B 2D n`; n = 0 off, 1 thin)

```dart
// commands.dart
const List<int> underlineOff  = [0x1B, 0x2D, 0x00];
const List<int> underlineThin = [0x1B, 0x2D, 0x01];

// receipt.dart
/// Prints [s] underlined.
///
/// ```dart
/// Receipt().underlined('Thank you');
/// ```
Receipt underlined(String s) => _add(UnderlinedTextOp(s));

// receipt_encoder.dart (inside the op switch)
case UnderlinedTextOp(:final text):
  out.add(underlineThin);
  out.add(latin1.encode('$text\n'));
  out.add(underlineOff);

// test
test('underlined wraps text with ESC - 1 / ESC - 0', () async {
  // OLD: final bytes = (ReceiptBuilder(PaperSize.mm80)..underlined('Hi')).build();
  final bytes = await encodeForTest(Receipt()..underlined('Hi'));
  expect(bytes, [0x1B,0x2D,0x01, 0x48,0x69,0x0A, 0x1B,0x2D,0x00]);
});
```

---

## Skill 2: Add a new transport (connection type)

**Steps**
1. Create `transports/<name>_transport.dart` implementing `PrinterTransport`.
2. Set `maxChunkSize` correctly for that medium.
3. Map every low-level failure to a `PrinterError` with `message` + `hint` (Skill 11).
4. If native code is needed, follow Skill 3.
5. Add `isSupported` logic per platform and a factory on `EscposPrinter`.
6. Add a test with a fake channel or local server.
7. Export it, and add a quick start line to `doc/quickstart.md`.

**Realistic example: timeout handling**

```dart
@override
Future<Result<void>> connect() async {
  try {
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    return const Result.ok(null);
  } on SocketException {
    return Result.error(PrinterError.connectionFailed(host: host, port: port));
  } on TimeoutException {
    return Result.error(PrinterError.timeout(host: host));
  }
}
```

Test: start `ServerSocket.bind('127.0.0.1', 0)`, connect, write `[0x1B,0x40]`, assert the server received exactly those bytes.

---

## Skill 3: Add a platform-channel method (Android/Kotlin)

**Steps**
1. Define the method and args in the contract table in `architecture.md`.
2. Implement in the Kotlin handler; run I/O off the main thread.
3. Return a value or an **error code string**; never crash.
4. Map the code to `PrinterError` in Dart.
5. Test the Dart side with a mocked channel.

**Realistic example: `bt.write`**

```kotlin
"bt.write" -> {
    val bytes = call.argument<ByteArray>("bytes")!!
    scope.launch(Dispatchers.IO) {
        try {
            socket.outputStream.write(bytes)
            socket.outputStream.flush()
            withContext(Dispatchers.Main) { result.success(true) }
        } catch (e: IOException) {
            withContext(Dispatchers.Main) { result.error("CONNECTION_LOST", e.message, null) }
        }
    }
}
```

```dart
} on PlatformException catch (e) {
  return Result.error(switch (e.code) {
    'CONNECTION_LOST'   => PrinterError.connectionLost,
    'PERMISSION_DENIED' => PrinterError.permissionDenied,
    _                   => PrinterError.unknown(detail: e.message),
  });
}
```

---

## Skill 4: Write a golden-bytes test

**When:** every change in `core/` that produces bytes.

**Steps**
1. Write the expected bytes by hand from the command reference (do not copy the output).
2. Encode with `encodeForTest`; compare with `expect`.
3. One command per test, plus one "full receipt" test.

**Realistic example: QR code** (`GS ( k` sequence)

```dart
test('qr("HI") emits model, size, ecc, store, print', () async {
  final bytes = await encodeForTest(Receipt()..qr('HI', size: 6));
  expect(bytes, [
    0x1D,0x28,0x6B,0x04,0x00,0x31,0x41,0x32,0x00,        // model 2
    0x1D,0x28,0x6B,0x03,0x00,0x31,0x43,0x06,              // module size 6
    0x1D,0x28,0x6B,0x03,0x00,0x31,0x45,0x31,              // error correction M
    0x1D,0x28,0x6B,0x05,0x00,0x31,0x50,0x30,0x48,0x49,    // store "HI" (length+3 = 5)
    0x1D,0x28,0x6B,0x03,0x00,0x31,0x51,0x30,              // print
  ]);
});
```

---

## Skill 5: Handle Android Bluetooth permissions

| Android version | Needed at runtime |
|---|---|
| 12+ (API 31+) | `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN` |
| 11 and below | location permission (scan only) |

**Steps:** check before every scan/connect; request if missing; if denied return
`PrinterError.permissionDenied` (with its hint); request only when the user taps "Find printer".

**Realistic example:** a waiter on Android 13 taps "Connect printer", sees the OS dialog, taps
Allow, and scanning starts. If they tap Deny, the UI shows `error.message` and the hint says what to enable.

---

## Skill 6: Debug "nothing prints" or "wrong text prints"

Work in this order and stop at the first failure.

| # | Check | How |
|---|---|---|
| 1 | Run `EscposLink.doctor()` | Reports missing permissions/manifest entries |
| 2 | Is the connection open? | Watch the `state` stream; call `connect()` |
| 3 | Did bytes leave the app? | Verbose log shows the byte count |
| 4 | Printer or code? | Call `printTestPage()`; or send only `ESC @`, `"TEST\n"`, `GS V 0` |
| 5 | Garbled Latin text (`Ã©` for `é`)? | Wrong code page; check the profile's `codePages` |
| 6 | **Boxes (tofu) instead of Bangla/CJK?** | Font missing: pass a font family or use the font pack |
| 7 | **Bangla letters split or vowel signs misplaced?** | Text went through the native path, or shaping was bypassed; force `TextMode.image` |
| 8 | **Chinese text with Japanese-looking shapes (or reverse)?** | Set `languageTag` (`'zh-Hans'` / `'ja'`) |
| 9 | Right edge cut off? | Profile `dotsWidth` too large (58 mm is about 384, not 576) |
| 10 | Prints half the receipt? | Missing flush, or Bluetooth chunks too big/fast |
| 11 | Image text is faint or tiny marks vanish? | Threshold too high; try dithering or a bolder font weight |
| 12 | Works once, then fails? | Socket not closed; add reconnect |

**Realistic example:** the cashier receipt shows empty boxes where the Chinese item name
should be. Cause: the Android tablet has no CJK font. Fix: register Noto Sans CJK in the app
and pass it in the text style, or install `escpos_link_fonts`.

---

## Skill 7: Implement the print queue

**Rules:** one job at a time per printer; FIFO; failed jobs retry 3 times (500 ms, 1 s, 2 s), then return the error.

**Realistic example:** at 8 PM two orders are submitted 100 ms apart.

```dart
final a = printer.print(orderA); // starts immediately
final b = printer.print(orderB); // waits until A finishes
await Future.wait([a, b]);       // paper shows A completely, then B
```

Test: `FakeTransport` with a 200 ms write delay; assert recorded bytes equal `A + B`, never interleaved.

---

## Skill 8: Print non-Latin text correctly (rewritten for multi-language)

**Why:** printers have few code pages and almost never have Bangla, Arabic, or Thai shaping.
Flutter's text engine already shapes them, so we draw the line as a picture and print the picture.

**Steps**
1. **Decide** native or image per line with the auto rule (architecture section 5.1). Never mix halves.
2. **Layout in pixels** with `renderRow` (price flush right), never with `padRight`.
3. **Render** with `FlutterTextRasterizer` at exactly `profile.dotsWidth` (no later resizing), black on white, passing `languageTag` as the paragraph locale and a `fontFamilyFallback` list.
4. **Convert to 1-bit** in an isolate (`compute`): threshold by default.
5. **Send in bands** of `profile.maxBandRows` rows using `GS v 0`.
6. **Cache** by `(text, style, width, languageTag)`.

**Note:** the rendering step (step 3) must run on the main isolate because it uses `dart:ui`; only the pixel conversion (step 4) goes to an isolate.

**Realistic example:** a restaurant prints `বার্গার x2 ........ 12.00`. The row becomes one
576-dot-wide bitmap: Bangla starts at the left edge, `12.00` ends at dot 576, and the
conjunct letters are joined exactly as on screen. The caller wrote only:

```dart
Receipt()..row('বার্গার x2', '12.00');
```

---

## Skill 9: Add or verify a language/script

**When:** adding support for a new language, or checking a reported bug.

**Steps**
1. Add 3-5 sample strings to `test/fixtures/languages.dart`: a simple word, a hard case, and a long line that must wrap.
2. Choose the strategy (native / image) and note it in the language table in `project_requirement.md`.
3. Confirm the **font fallback** has the script and set the **language tag** if Han or similar characters are involved.
4. Check **direction** (RTL for Arabic/Hebrew) and **wrapping** (Skill 8, architecture section 5.3).
5. Create a golden image (Skill 12), then **look at it** and approve it by eye.
6. Print on a real printer (58 mm and 80 mm) and record the result in the `tasks.md` test matrix.
7. Add a recipe to `doc/cookbook.md`.

**Realistic example: Bangla hard cases**

| Sample | What to check |
|---|---|
| `ধন্যবাদ` | Joined cluster `ন্য` and `দ` |
| `ক্ষ`, `স্ত্র` | Conjuncts are single shapes, not `ক ্ ষ` |
| `কি`, `কু` | Small vowel signs visible after 1-bit conversion |
| `বার্গার x2 ... 12.00` | Price flush right on both paper widths |

**Realistic example: Han unification.** The same character (e.g. 直 or 骨) can look different in a
Chinese and a Japanese font. Add one fixture with `languageTag: 'zh-Hans'` and one with `'ja'`
and compare the two golden images.

---

## Skill 10: Design a beginner-friendly API (the "3-line test")

**When:** adding or changing anything public.

**Steps**
1. Write the **usage first**, as a README snippet. If a beginner needs more than about 3 lines for the common case, redesign.
2. Give every parameter a **sensible default**; make only the truly necessary ones `required`.
3. Use **enums and named parameters**, not strings or positional booleans.
4. Hide bytes, chunk size, MTU, code pages, and band height. Put them in `advanced.dart`.
5. Add a `///` doc with a runnable example and a one-line plain explanation of any jargon.
6. Add a **debug assert** with a plain-language message for common mistakes.

**Realistic example**

```dart
// BAD: beginner must know bytes and transports
final t = NetworkTransport('192.168.1.50', 9100);
await t.connect();
await t.write(ReceiptEncoder(profile, rasterizer).encodeSync(receipt));
await t.disconnect();

// GOOD: 2 lines, same result
final printer = EscposPrinter.wifi('192.168.1.50');
await printer.print(Receipt()..text('Hello')..cut());
```

```dart
// Plain-language assert
assert(width <= profile.dotsWidth,
    'This image is $width dots wide but the printer fits ${profile.dotsWidth}. '
    'Resize it, or use Receipt.image(logo, fit: ImageFit.width).');
```

---

## Skill 11: Write a friendly error (`message` + `hint`)

**Rules**
- `message` says **what happened** in plain words, with no stack-trace language.
- `hint` says **what to do next**, with the exact setting or code to change.
- Include useful details (host, port, address) but never secrets.

**Realistic example**

```dart
static PrinterError connectionFailed({required String host, required int port}) => PrinterError(
  PrinterErrorCode.connectionFailed,
  message: 'Could not connect to the printer at $host:$port.',
  hint: 'Check that the printer is on, is on the same WiFi as this device, '
        'and that the IP is right (print its self-test page to see the IP). '
        'Most network printers use port 9100.',
);
```

Test: assert both `message` and `hint` are non-empty for **every** `PrinterErrorCode`.

---

## Skill 12: Write a golden-image test for text layout

**When:** any change to wrapping, rows, fonts, direction, or 1-bit conversion.

**Steps**
1. Use `FlutterTextRasterizer` in a `testWidgets` with a bundled test font (so results are the same on every machine).
2. Render each fixture at 384 and 576 dots, then call `expectLater(image, matchesGoldenFile(...))`.
3. Run `flutter test --update-goldens`, then **open the PNGs and check them by eye**: joined letters, alignment, no clipping.
4. Commit the PNGs. In review, treat a changed PNG as a changed behaviour.

**Realistic example:** the test renders `row('বার্গার x2', '12.00')` at 384 dots and compares to
`goldens/bangla_row_58mm.png`. A refactor accidentally right-pads by 4 dots; the golden test
fails and shows the price is no longer flush right.

---

## Skill 13: Write beginner docs and cookbook recipes

**Steps**
1. Each recipe has a **goal sentence**, a **copy-paste snippet**, the **expected paper output** (ASCII sketch or image), and **one common mistake**.
2. Keep each page short. Link to `glossary.md` for jargon.
3. Test every snippet in the example app before publishing it.

**Realistic recipe: "Print a Bangla receipt over WiFi"**

````markdown
## Print a Bangla receipt over WiFi
Goal: print an item row in Bangla with the price on the right.

```dart
final printer = EscposPrinter.wifi('192.168.1.50');
await printer.print(Receipt()..row('বার্গার x2', '12.00')..cut());
```

Paper:      বার্গার x2          12.00

Common mistake: seeing empty boxes instead of letters means the device has no Bangla font.
See troubleshooting.md, "Boxes instead of letters".
````

---

## Skill 14: Prepare a release

1. `flutter analyze` and `flutter test` (including goldens) are clean.
2. Update `pubspec.yaml` version and `CHANGELOG.md`.
3. README quick start, platform setup (manifest, `Info.plist`), and the language table are current.
4. Run the example app and `printTestPage()` on one real printer per transport, including Bangla, Chinese, and Japanese lines.
5. A new developer follows only the README and reaches a printed test page in under 15 minutes (ask someone to try).
6. `dart pub publish --dry-run`, fix warnings, publish, and tag in Git.

---

## Skill 15: Safely modify existing code

Follow the rule from `CLAUDE.md`: keep the old code as a comment next to the new code.

```dart
// OLD: socket.write(bytes);
socket.add(bytes); // NEW: add() sends raw bytes; write() would convert the list to a String
await socket.flush(); // flush() is the part that returns a Future
```

Then explain in one or two sentences **why** it changed, with a concrete scenario.
