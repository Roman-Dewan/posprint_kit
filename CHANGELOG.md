## 0.0.1

<!-- OLD: * TODO: Describe initial release. -->
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
