# CLAUDE.md: Agent Entry Point (v2)

> Read this file first, every session. It tells you what this project is, which
> files to read next, and the rules you must follow.

## Project in one sentence

`escpos_link` (working name) is a reusable Flutter plugin that prints receipts in
**ESC/POS mode** over **WiFi, Bluetooth, and USB**, in **any language** (English,
Bangla, Chinese, Japanese, Korean, Arabic, Hindi, Thai...), with an API a **junior
developer** can use without knowing ESC/POS.

**Example of the goal:** the same code prints a mixed Bangla + English receipt on a
WiFi kitchen printer, a USB cashier printer, and a Bluetooth waiter printer:

```dart
final printer = EscposPrinter.wifi('192.168.1.50');
await printer.print(
  Receipt()
    ..title('মাই রেস্টুরেন্ট')
    ..row('বার্গার x2', '12.00')
    ..cut(),
);
```

## Two audiences, two rules

1. **Users of the package are often junior developers.** Simple by default,
   powerful when needed. Common tasks must take about 3 lines.
2. **Printed receipts are read by real customers in many languages.** Text must
   look correct: joined letters, right alignment, no clipped or garbled lines.

## Read order

1. `project_requirement.md`: WHAT we build and why (including DX and language requirements)
2. `architecture.md`: HOW it is structured (layers, text engine, interfaces, folders)
3. `skills.md`: step-by-step playbooks for common tasks
4. `tasks.md`: the work queue; pick the first unchecked task unless told otherwise

## Golden rules

1. **Core stays pure Dart.** Nothing in `lib/src/core/` or
   `lib/src/transports/network_transport.dart` may import `package:flutter` or `dart:ui`.
   Code that needs Flutter's text engine lives only in `lib/src/rendering/` and `lib/src/ui/`.
   *Example:* the core defines `abstract class TextRasterizer`; only
   `FlutterTextRasterizer` (in `rendering/`) imports `dart:ui`.
2. **Every ESC/POS command gets a golden-bytes test.** Every text-layout feature gets a
   golden-image test (see `skills.md`, Skills 4 and 12).
3. **Beginner-first API (the "3-line test").** A junior must be able to do the common
   case in about 3 lines, with no knowledge of bytes, MTU, code pages, or ESC/POS.
   Advanced knobs go in `lib/advanced.dart`, never in the main API.
4. **No exceptions across the public API.** Return `Result<T>`. Every `PrinterError` has a
   `message` (what happened) and a `hint` (how to fix it), written for beginners.
5. **Never assume 1 character = 1 byte = 1 column.** Bangla letters join into clusters,
   Chinese/Japanese characters are double width, Arabic runs right-to-left.
   Do not hand-roll glyph shaping. Use Flutter's text engine through `TextRasterizer`.
   Default text mode is `TextMode.auto`.
6. **Chunk Bluetooth/BLE writes.** Never send a full receipt in one write.
7. **Ask before** adding a dependency, changing a public API signature, bundling fonts,
   or changing Android permissions.
8. **Do not guess printer behaviour.** If unsure about a byte sequence, a printer's
   code page, or its built-in CJK font, say so and point to the printer manual instead
   of inventing it.

## Code modification rule (important)

When you change existing code, **keep the old code as a comment right next to the new
code**, marked with `// OLD:`. Do not delete it silently.

```dart
// OLD: final socket = await Socket.connect(host, port);
final socket = await Socket.connect(
  host,
  port,
  timeout: const Duration(seconds: 5), // NEW: avoids hanging forever on a dead IP
);
```

## Explanation and documentation rules

- When you explain a concept or decision, include a **short realistic example**
  (e.g. "a restaurant at 8 PM rush with two orders arriving in one second").
- Write docs for a beginner. Any jargon (MTU, code page, raster, dithering) gets a
  one-line plain explanation the first time it appears.
- Error messages and hints are documentation too (Skill 11).

## Commands

```bash
flutter pub get                    # install dependencies
dart format .                      # format
flutter analyze                    # static analysis (must be clean)
flutter test                       # unit + golden tests (must pass)
flutter test --update-goldens      # regenerate golden images (review the diff by eye!)
cd example && flutter run          # run the demo app
```

## Definition of done (for every task)

- [ ] `flutter analyze` has zero warnings
- [ ] `flutter test` passes, with new tests for new behaviour
- [ ] Public API additions have `///` doc comments with a usage example
- [ ] The 3-line test is satisfied for any user-facing change
- [ ] New errors have a clear `message` and `hint`
- [ ] Text/layout changes include a golden image checked with the language fixtures
      (Bangla, Chinese, Japanese at minimum)
- [ ] `CHANGELOG.md` updated, and the task checked off in `tasks.md`

## Do NOT

- Do not hardcode printer IPs, MAC addresses, or USB vendor IDs.
- Do not use `print()` for logging; use the package logger.
- Do not block the UI thread with image conversion (1-bit conversion runs in an isolate).
- Do not print non-Latin text by mapping characters to bytes yourself.
- Do not commit generated build folders.
