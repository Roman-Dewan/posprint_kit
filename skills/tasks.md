# tasks.md: Work Queue (v2)

> The agent picks the **first unchecked task** unless told otherwise.
> Check a task off only when it meets the *Definition of done* in `CLAUDE.md`.
>
> **v2 changes:** new Phase 5 (multi-language text engine) and Phase 9 (beginner
> experience); tasks renumbered because no work had started yet. IDs are stable from now on.

Legend: `[ ]` todo, `[~]` in progress, `[x]` done, `[!]` blocked (add a note)

---

## Phase 0: Setup

- [ ] **T-001** Scaffold: `flutter create --template=plugin --platforms=android,ios escpos_link`
- [ ] **T-002** Create the folder structure from `architecture.md` section 3 (including `doc/`, `rendering/`, `test/fixtures/`)
- [ ] **T-003** `analysis_options.yaml` (strict lints) and a package logger with `LogLevel`
- [ ] **T-004** CI (GitHub Actions): `flutter analyze` + `flutter test`
- [ ] **T-005** `test/fixtures/languages.dart` with sample strings (Latin accents, Bangla, Hindi, Chinese, Japanese, Korean, Arabic, Thai)

**Done when:** a fresh clone runs `flutter test` successfully.

---

## Phase 1: Core receipt and encoder (pure Dart, native text only)

- [ ] **T-101** `Result<T>`, `PrinterError(message, hint)`, `PrinterErrorCode`, and `Result.when`
- [ ] **T-102** `commands.dart` constants: `ESC @`, LF, align, bold, underline, size, cut
- [ ] **T-103** `Receipt` (ops list) and `ReceiptEncoder.encode()` with `text()` (align, bold, size), plus `encodeForTest` helper
- [ ] **T-104** `PrinterProfile` (`dotsWidth`, presets `generic58`, `generic80`) and character columns for native text
- [ ] **T-105** `row(left, right)` for native text, `divider()`, `feed()`, `title()`, `total()`
- [ ] **T-106** `cut()` (full and partial)
- [ ] **T-107** `qr()` (see Skill 4)
- [ ] **T-108** `barcode()` (CODE128, EAN13)
- [ ] **T-109** `drawer()` pulse (`ESC p`)
- [ ] **T-110** `CodePageEncoder` + `ESC t n` for Latin accents (CP437 / CP858 / CP1252 tables)
- [ ] **T-111** `Receipt.simple(...)` template

**Done when:** an English receipt encodes to bytes and a full-receipt golden-bytes test passes.

**Realistic check:**

```
        MY RESTAURANT
--------------------------------
Burger x2               12.00
Cola x1                  2.00
--------------------------------
TOTAL                   14.00
        [QR CODE]
        (paper cut)
```

---

## Phase 2: Transport abstraction, fake, and beginner facade

- [ ] **T-201** `PrinterTransport` interface + `ConnectionState`
- [ ] **T-202** `FakeTransport` (records bytes, optional delay and failure injection)
- [ ] **T-203** `EscposPrinter` facade: `.wifi()`, `.bluetooth()`, `.usb()`, `print()`, `close()` (the **3-line test**)
- [ ] **T-204** `EscposLink.isSupported(Transport)` and `logLevel`
- [ ] **T-205** Friendly error catalog: `message` + `hint` for every `PrinterErrorCode`, with a test that none are empty (Skill 11)
- [ ] **T-206** `lib/advanced.dart` split (raw bytes, custom commands, chunk size)
- [ ] **T-207** Debug asserts with plain-language messages (Skill 10)

---

## Phase 3: WiFi / Network transport

- [ ] **T-301** `NetworkTransport` (TCP, port 9100, 5 s connect timeout)
- [ ] **T-302** Map `SocketException` / `TimeoutException` to friendly errors
- [ ] **T-303** Integration test against a local `ServerSocket`
- [ ] **T-304** Reconnect when the socket closes unexpectedly
- [ ] **T-305** *(optional)* LAN discovery: scan the subnet for open port 9100
- [ ] **T-306** Example app screen: enter an IP, print the sample receipt

**Manual device check:** print the sample receipt on a real WiFi printer.

---

## Phase 4: Print manager (queue)

- [ ] **T-401** `PrintQueue`: FIFO, one job at a time (Skill 7)
- [ ] **T-402** Retry with backoff (500 ms, 1 s, 2 s)
- [ ] **T-403** `PrinterManager` with a `state` stream; `EscposPrinter.print` uses it
- [ ] **T-404** Chunked writes using `transport.maxChunkSize`
- [ ] **T-405** Tests: ordering, retry, correct `PrinterError` surfaced

---

## Phase 5: Multi-language text engine (new)

> Needs only Phases 1-2 and `FakeTransport`; it can start before any Bluetooth/USB work.

- [ ] **T-501** `TextRasterizer` interface, `GrayBitmap`, `MonoBitmap`, `FakeRasterizer` (core, pure Dart)
- [ ] **T-502** `FlutterTextRasterizer` in `rendering/`: `renderText`, paragraph locale from `languageTag`, `fontFamilyFallback`
- [ ] **T-503** 1-bit conversion in an isolate: threshold (default) and optional dithering
- [ ] **T-504** `GS v 0` encoder with **bands** (`maxBandRows`), golden-bytes tested
- [ ] **T-505** `TextEngine` auto decision per line (native vs image) driven by `PrinterProfile.codePages`
- [ ] **T-506** `renderRow`: pixel layout with price flush right (left wraps in the remaining width)
- [ ] **T-507** Pixel-based wrapping: spaces for Bangla/Latin, per-character for CJK, closing-punctuation rule
- [ ] **T-508** Right-to-left support (Arabic/Hebrew): direction, alignment, mixed numbers
- [ ] **T-509** `TextMetrics` display width (full-width = 2 columns) for native CJK
- [ ] **T-510** Line cache keyed by `(text, style, width, languageTag)`
- [ ] **T-511** Golden-image tests for all fixtures at 384 and 576 dots (Skill 12). **Review each PNG by eye.**
- [ ] **T-512** Han unification test: same characters with `'zh-Hans'` vs `'ja'`
- [ ] **T-513** Bangla hard cases: conjuncts, vowel signs surviving 1-bit conversion (Skill 9)
- [ ] **T-514** Font strategy: system fonts default, app-supplied font option; decide on optional `escpos_link_fonts` (update ADR #9)
- [ ] **T-515** Widget-to-image printing (`widget_rasterizer.dart`)
- [ ] **T-516** `Receipt.image()` for logos (resize to width, 1-bit)
- [ ] **T-517** Opt-in native CJK via profile flags (check printer manual and a real device; ADR #12)

**Done when:** a mixed Bangla + Chinese + Japanese + English receipt renders to correct golden images
and encodes to bytes through `FakeTransport`.

**Realistic check (80 mm):**

```
          মাই রেস্টুরেন্ট
-------------------------------
Burger x2                 12.00
বার্গার x1                 6.00
チキンカレー x1             9.00
这是一个很长的中文菜名需要换行      <- wraps, not clipped
-------------------------------
TOTAL                     27.00
```

---

## Phase 6: Android Bluetooth Classic (SPP)

- [ ] **T-601** Kotlin `BluetoothHandler`: list paired devices
- [ ] **T-602** Connect / write / disconnect on a background thread
- [ ] **T-603** Runtime permission flow (Skill 5)
- [ ] **T-604** `BluetoothTransport` + friendly error mapping
- [ ] **T-605** Example app screen: choose a paired printer, print
- [ ] **T-606** Link drop mid-print: reconnect and resend the job
- [ ] **T-607** Measure image-heavy receipt speed over Bluetooth and tune chunk size/delay

**Manual device check:** pair a 58 mm printer, print the multi-language receipt, switch the printer off mid-job and confirm a clean error with a hint.

---

## Phase 7: Android USB

- [ ] **T-701** Kotlin `UsbHandler`: list devices, find the printer interface and OUT endpoint
- [ ] **T-702** Permission request flow (`UsbManager.requestPermission`)
- [ ] **T-703** Bulk-transfer write in chunks
- [ ] **T-704** Handle detach events (cable pulled)
- [ ] **T-705** `UsbTransport` + friendly error mapping
- [ ] **T-706** Example app screen + manual check with an OTG cable

---

## Phase 8: BLE (Android + iOS)

- [ ] **T-801** Decide: build on `flutter_blue_plus` or own native code (record in the ADRs)
- [ ] **T-802** `BleTransport` with MTU-aware chunking and a small inter-chunk delay
- [ ] **T-803** iOS `Info.plist` setup docs
- [ ] **T-804** Manual check on a BLE printer

---

## Phase 9: Beginner experience (new)

- [ ] **T-901** `printTestPage()`: ruler, QR, one line per language (Bangla, Chinese, Japanese, Korean, Arabic, Hindi, Thai)
- [ ] **T-902** `EscposLink.doctor()`: permissions, manifest entries, USB host feature, reachability (Android `doctor.check`)
- [ ] **T-903** `ReceiptPreview` widget (same rasterizer, same widths)
- [ ] **T-904** Printer presets: `epsonTmT20`, `xprinter58` (only after testing real models)
- [ ] **T-905** `PrinterPicker` drop-in widget (scan, choose, remember)
- [ ] **T-906** `doc/quickstart.md`: 3-line start for WiFi, Bluetooth, USB
- [ ] **T-907** `doc/cookbook.md`: recipes for Bangla, Chinese, Japanese, Arabic, QR, logo, two-column rows, preview (Skill 13)
- [ ] **T-908** `doc/troubleshooting.md`: nothing prints, boxes instead of letters, split Bangla letters, wrong Han glyphs, cut-off edge
- [ ] **T-909** `doc/glossary.md`: code page, raster, band, dithering, MTU, ESC/POS in plain words
- [ ] **T-910** Example app: one recipe per screen
- [ ] **T-911** **Usability test:** a new developer, using only the README, prints the test page in under 15 minutes. Record problems and fix the docs/API.

---

## Phase 10: Extras

- [ ] **T-1001** Printer status via `DLE EOT` (paper out, cover open)
- [ ] **T-1002** Printer profiles from real-device findings (58/80 mm, code pages, quirks)
- [ ] **T-1003** Saved printers (persist in app storage)

---

## Phase 11: Release

- [ ] **T-1101** README: install, per-platform setup, API tour, **language support table**
- [ ] **T-1102** `///` docs with examples on every public member
- [ ] **T-1103** Decide the final package name and single vs multi-package (update ADR #4)
- [ ] **T-1104** Release checklist (Skill 14) and `dart pub publish --dry-run`

---

## Manual test matrix (fill in as you go)

| Printer model | Paper | WiFi | Bluetooth | USB | Latin | Bangla | Chinese | Japanese | Notes |
|---|---|---|---|---|---|---|---|---|---|
| *(e.g. Epson TM-T20)* | 80 mm | [ ] | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | |
| *(e.g. Xprinter XP-58)* | 58 mm | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | |

## Blockers / notes

*(Add dated notes here, e.g. "2026-11-02: Xprinter ignores partial cut; use full cut.")*
