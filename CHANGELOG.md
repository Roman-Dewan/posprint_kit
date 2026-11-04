## 1.1.0

* **Sunmi Built-in POS Terminal Integration (`SunmiTransport` & `EscposPrinter.sunmi`)**:
  - Direct integration with Sunmi's official PrinterX SDK (`com.sunmi:printerx`) and Inner Printer Library (`com.sunmi:printerlibrary`) via native Android MethodChannel bridge (`SunmiHandler.kt`).
  - Supports Sunmi D3 desktop POS terminals (with integrated 80 mm high-speed 250 mm/s thermal printer and auto-cutter) as well as handhelds (Sunmi V2, V2s, T2, etc.).
  - Added `EscposPrinter.sunmi()` and `EscposPrinter.inbuilt()` 3-line facades.
  - Native `LineApi` architecture (`sunmi.printReceipt`) executing fonts, alignments, multi-column tables (`Receipt.columns`), and dashed dividers natively on Sunmi thermal hardware.
  - Fixed paper feed line pitch: correctly scales `Receipt.feed(lines)` to standard thermal line pitch (32 dots per line in `LineApi.printDividingLine(DividingLine.EMPTY, lines * 32)`) ensuring consistent vertical whitespace before QR codes, barcodes, and paper cuts.
  - Emits genuine dashed hyphens (`- - - - -`) for `receipt.divider()` matching traditional thermal receipt styling.
  - Dual-channel cash drawer triggering: tries AIDL `InnerPrinterManager` / `IWoyouService.openDrawer()` with 100 ms ESC/POS pulse fallback.
  - Hardware paper roll inquiry (`SunmiTransport.getPaperWidth()`) returning 80 mm or 58 mm.
  - Device detection (`SunmiTransport.isSunmiDevice()`) and real-time printer status inquiry (`SunmiTransport.getStatus()`).
  - Added Android 11+ package visibility declaration (`<queries><package android:name="woyou.aidlservice.jiuiv5" /></queries>`) in `AndroidManifest.xml`.
  - Added Built-in (Sunmi) transport option to `PrinterPicker` and a dedicated Sunmi printing tab to the example app.

* **100% Universal Thermal Raster QR Code Engine (`QrRasterizer` & `GS v 0`)**:
  - Automatically converts QR codes into crisp, high-contrast 1-bit monochrome raster bitmaps (`MonoBitmap`) conforming to the ISO/IEC 18004 specification with a 4-module quiet zone.
  - Fixes missing QR codes on WiFi, Bluetooth, and USB thermal printers (such as Xprinter, Zjiang, Rongta, POS-58, POS-80) whose firmware lacks Epson's proprietary `GS ( k` 2D barcode command.
  - Added `PrinterProfile.useRasterQr` (defaults to `true`) to guarantee 100% printer compatibility out of the box while preserving legacy hardware `GS ( k` as an opt-in fallback with trailing `LF` line flushing.
  - Added horizontal alignment support (`PosAlign.center`, `PosAlign.left`, `PosAlign.right`) to `Receipt.qr()`.

* **Customizable Typography & Title Font Sizing**:
  - `Receipt.title()` now supports a custom `fontSize` parameter (defaults to prominent 36 pt double-size title).
  - Dynamic font size forwarding in `SunmiTransport` and `SunmiHandler.kt` respecting custom `TextStyleSpec.fontSize` and synchronizing with both `TextStyle.setTextSize` and Sunmi AIDL `setFontSize`.

## 1.0.1

* **Bluetooth Classic Printing Reliability & UART Pacing Fix**:
  - Implemented inter-chunk pacing delay (`chunkDelay: const Duration(milliseconds: 25)`) and 256-byte chunking (`maxChunkSize: 256`) in `BluetoothTransport` and `PrinterManager` to prevent microcontrollers on portable thermal printers from overflowing their UART receive buffers.
  - Resolved print stalls and freezes when printing raster images or multi-language receipts (`GS v 0`) over Bluetooth Classic RFCOMM SPP.
  - Added graceful 400 ms RFCOMM socket drain delay in Kotlin `BluetoothHandler.kt` and `BluetoothTransport.disconnect()` to prevent cutting off receipts mid-print when `printer.close()` is invoked immediately after `printer.print()`.
  - Configured `PrinterProfile.generic58` and `xprinter58` with safe image band height (`maxBandRows: 32`) so raster chunks fit within compact 2 KB printer RAM.
  - Added paper profile width selector (58 mm / 80 mm) to the Bluetooth screen in the example application.

## 1.0.0

* **LAN / WiFi Printer Discovery (`NetworkDiscovery` & `NetworkDevice`)**:
  - Auto-discover thermal printers across the local network subnet over TCP port 9100.
  - Returns typed `NetworkDevice` containing device `ip`, `port`, `name`, and `model`.
  - Reverse DNS hostname resolution and ESC/POS hardware inquiry (`GS I 67` / `GS I 2`) to identify printer model.
  - Added `NetworkTransport.discoverDevices()` and `NetworkTransport.listDevices()`.
  - Added `EscposPrinter.network(device)` and `EscposPrinter.discoverWifi()`.
  - Added network scanning to `PrinterPicker` and example application.
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
