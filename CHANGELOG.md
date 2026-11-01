## 1.0.0 (stable)

* **Multi-Column Printing (`Receipt.columns`)**:
  - Support for 3, 4, 5+ columns (e.g., `[SL, Item Name, Qty, Price, Total]`).
  - Configurable flex ratios (`width: 1`, `width: 5`), per-column alignment, clean whitespace, and multi-line wrapping.
  - Monospace text engine formatter for pure Latin/ASCII rows and pixel-perfect isolate-backed rasterization for 58 mm (384 dots) and 80 mm (576 dots).
* **Guaranteed 14-Language Engine**:
  - Full support for Latin, German, Portuguese, Turkish, Bangla, Hindi, Tamil, Telugu, Arabic (RTL), Hebrew, Chinese, Japanese, Korean, and Thai.
  - Automatic font fallback resolution including `Noto Sans Tamil` and `Noto Sans Telugu`.
* **Unified Transports**:
  - WiFi / LAN (port 9100) with automatic reconnection on disconnect.
  - Android Bluetooth Classic (SPP / RFCOMM) with paired device discovery and Android 12+ runtime permission flows.
  - Android USB OTG / Direct bulk OUT transfers with auto-permission request.
* **Developer Experience**:
  - Simplified, beginner-friendly example application with clear 3-step printing flow.
  - Drop-in `ReceiptPreview` widget and `PrinterPicker` dialog.
  - Diagnostics tool (`EscposLink.doctor()`) and hardware calibration test (`printTestPage()`).

## 0.0.1

* Phase 0 Setup:
  - Plugin scaffold verified with strict analysis options (`analysis_options.yaml`).
  - Folder structure and architecture documentation (`doc/quickstart.md`, `cookbook.md`, `troubleshooting.md`, `glossary.md`).
  - Package logger with `LogLevel` (`PosLogger`).
  - GitHub Actions CI workflow (`.github/workflows/ci.yml`).
  - Multi-language test fixtures (`test/fixtures/languages.dart`).
* Phase 1 Core Receipt & Encoder:
  - `Result<T>` with pattern matching & `.when()` helper, `PrinterError` with plain-language `message` and `hint`.
  - ESC/POS byte sequence constants in `Commands`.
  - Fluent `Receipt` builder with operations (`text`, `row`, `divider`, `feed`, `title`, `total`, `cut`, `qr`, `barcode`, `drawer`, `image`).
  - `ReceiptEncoder` with asynchronous encoding, code page selection, two-column native row formatting, and golden-bytes tests.
  - `PrinterProfile` with 58 mm and 80 mm presets (`generic58`, `generic80`, `epsonTmT20`, `xprinter58`).
  - `CodePageEncoder` with CP437, CP850, CP858, and CP1252 tables.
  - `Receipt.simple` quick-start template.
* Phase 2 Transport Abstraction & Facade:
  - `PrinterTransport` interface and `PosConnectionState`.
  - In-memory `FakeTransport` with byte recording, artificial delays, and failure injection.
  - Beginner-friendly `EscposPrinter` facade satisfying the 3-line quick start test.
  - `EscposLink.isSupported(Transport)` and `logLevel`.
  - Advanced tools separated into `package:posprint_kit/advanced.dart`.
  - Helpful debug assertions with plain-English instructions.
* Phase 3 Network / WiFi Transport:
  - Pure Dart `NetworkTransport` communicating over TCP (port 9100, 5 s timeout).
  - Friendly error mappings for `SocketException` and `TimeoutException`.
  - Automatic reconnection before write operations if socket disconnected.
  - Integration tests with `ServerSocket`.
* Phase 4 Print Queue & Manager:
  - FIFO `PrintQueue` ensuring single-job concurrency per printer and preventing byte interleaving.
  - Exponential backoff retry (500 ms, 1 s, 2 s) on transient failures.
  - `PrinterManager` with connection state stream and automatic chunking via `maxChunkSize`.
  - Integration tests verifying job execution ordering and retry error surfacing.
* Phase 5 Multi-Language Text Engine:
  - `FlutterTextRasterizer` in `lib/src/rendering/` for pixel-accurate text shaping across Bangla, Hindi, Chinese, Japanese, Arabic, and Thai.
  - Pixel-based row layout (`renderRow`) with right column flush against right margin on 58 mm and 80 mm profiles.
  - Background isolate 1-bit monochrome thresholding via `BitmapConverter.toMonoAsync`.
  - Line raster cache keyed by text, style, dots width, and language tag.
  - `WidgetRasterizer` for printing arbitrary Flutter widgets as thermal receipts.
  - `ReceiptPreview` widget displaying visual on-screen receipts without physical printers.
  - Tests for Han unification (zh-Hans vs ja) and Bangla conjuncts/vowel mark retention.
  - Added test fixtures for all 14 guaranteed languages (`test/fixtures/languages.dart`), including Tamil (`ta`), Telugu (`te`), Turkish (`tr`), German (`de`), and Portuguese (`pt`).
  - Added `Noto Sans Tamil` and `Noto Sans Telugu` to default `fontFamilyFallback` in `FlutterTextRasterizer`.
  - Added `PosColumn` class, `ColumnsOp`, and fluent `Receipt.columns(...)` API for 3, 4, 5+ column layouts with flex ratios and per-column alignment.
  - Monospace multi-column formatter in `TextEngine.formatNativeColumns` with clean whitespace padding and multi-line auto-wrapping.
  - Pixel-perfect `FlutterTextRasterizer.renderColumns` with top-aligned multi-line cell wrapping for 58 mm (384 dots) and 80 mm (576 dots).
  - Multi-column recipe in `doc/cookbook.md` and interactive 5-column order screen in `example/lib/main.dart`.
* Phase 6 Android Bluetooth Classic (SPP):
  - Native Kotlin `BluetoothHandler` listing paired devices, opening RFCOMM sockets over standard SPP UUID (`00001101-0000-1000-8000-00805F9B34FB`), and writing bytes on `Dispatchers.IO`.
  - `BluetoothTransport` and `BluetoothDevice` with `listPairedDevices()`.
  - Friendly error mappings for `BLUETOOTH_DISABLED`, `PERMISSION_DENIED`, and socket disconnects.
  - `EscposPrinter.bluetooth(address)` facade constructor.
* Phase 7 Android USB (OTG / Direct):
  - Native Kotlin `UsbHandler` discovering USB devices, identifying bulk OUT endpoints, and requesting device permissions via `UsbManager.requestPermission`.
  - `UsbTransport` and `UsbDevice` with `listDevices()` and `requestPermission()`.
  - Friendly error mappings for missing USB permission and device disconnections.
  - `EscposPrinter.usb(vendorId: ..., productId: ...)` facade constructor.
* Phase 9 Beginner Experience:
  - `printTestPage()` method outputting calibration ruler, QR code, and sample lines across all supported languages.
  - `EscposLink.doctor()` diagnostics utility checking OS capabilities, network permissions, and transport support.
  - Drop-in `PrinterPicker` widget for searching, configuring, and testing WiFi, Bluetooth, and USB thermal printers.
  - Example app updated with dedicated WiFi, Bluetooth, and USB device scanning, selection, receipt printing, and diagnostic test page execution.
  - Documentation set in `doc/`: `quickstart.md`, `cookbook.md`, `troubleshooting.md`, `glossary.md`.
