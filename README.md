# posprint_kit

[![Pub Version](https://img.shields.io/pub/v/posprint_kit)](https://pub.dev/packages/posprint_kit)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)
[![Flutter Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg)](https://flutter.dev)

A beginner-friendly, multi-language Flutter plugin for printing thermal receipts (**ESC/POS**) and sticker labels (**TSPL**) over **WiFi, Bluetooth, and USB**, supporting any language (English, Bangla, Arabic, Chinese, Japanese, Korean, Hindi, Tamil, Telugu, and more).

---

## The 3-Line Quick Start

Print a receipt to any ESC/POS thermal printer in about 3 lines without touching raw bytes, code pages, or hex commands:

```dart
import 'package:posprint_kit/posprint_kit.dart';

void main() async {
  // 1. Connect to printer (WiFi, Bluetooth, USB, or Sunmi Built-in)
  final printer = EscposPrinter.wifi('192.168.1.50');

  // 2. Build your receipt with the fluent API
  final receipt = Receipt()
    ..title('MY RESTAURANT', fontSize: 36)
    ..text('Table 4 • Dine-in • Order #1042', align: PosAlign.center)
    ..divider()
    ..row('Burger x2', '12.00')
    ..row('বার্গার x1', '6.00', languageTag: 'bn') // Bangla auto-rendered
    ..divider()
    ..total('TOTAL', '18.00')
    ..qr('https://github.com/roman-dewan/posprint_kit', size: 6)
    ..cut();

  // 3. Print!
  await printer.print(receipt);
  await printer.close();
}
```

---

## Key Features

* **3-Line Beginner API**: Print immediately without understanding ESC/POS specifications, baud rates, or hex buffers.
* **100% Universal QR Codes**: Built-in 1-bit thermal raster engine ensures QR codes print sharply on 100% of WiFi, Bluetooth, and USB printers, bypassing buggy or missing printer firmware `GS ( k` support.
* **Guaranteed 14 Languages**: Built-in shaping and automatic 1-bit thermal rasterization for complex Asian, Indic, and Middle Eastern scripts.
* **Multi-Column Tables (`Receipt.columns`)**: Build 3, 4, 5+ column POS receipts (`[#, Item, Qty, Price, Total]`) with customizable flex ratios, alignments, and multi-line wrapping.
* **Unified Transports**: Connect over **WiFi / LAN** (TCP port 9100), **Bluetooth Classic** (Android SPP), **USB OTG / Direct**, and **Sunmi Built-in Printers** (Sunmi D3, V2, T2 via native `LineApi`) with auto-permissions and cash drawer kick.
* **Non-Interleaving Print Queue**: FIFO background queue prevents multiple prints from corrupting each other, with automatic exponential backoff retry.
* **Friendly Errors**: Every failure returns a typed `Result<T>` with a beginner-friendly `message` and an actionable `hint`.
* **Zero-Waste UI Tools**: Live on-screen `ReceiptPreview` widget and drop-in `PrinterPicker` connection dialog.
* **Environment Diagnostics**: Built-in `EscposLink.doctor()` checks OS permissions and printer hardware reachability.

---

## Platform Setup

### Android (`android/app/src/main/AndroidManifest.xml`)

Add the following permissions depending on the transports you use:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- WiFi / LAN printing -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Bluetooth Classic printing (Android 12+) -->
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                     android:usesPermissionFlags="neverForLocation" />

    <!-- Bluetooth Classic printing (Android 11 and lower) -->
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

    <!-- USB OTG printing -->
    <uses-feature android:name="android.hardware.usb.host" android:required="false" />

    <!-- Sunmi POS terminal built-in printer service (Android 11+) -->
    <queries>
        <package android:name="woyou.aidlservice.jiuiv5" />
    </queries>
</manifest>
```


## Multi-Column Receipts (`Receipt.columns`)

Print realistic multi-column POS order slips with flexible width ratios (`flex`), per-column alignment (`left`, `center`, `right`), clean whitespace, and automatic cell wrapping:

```dart
final receipt = Receipt()
  ..title('BISTRO ORDER')
  ..divider()
  // Table Header (1:5:1:2:2 ratio)
  ..columns([
    const PosColumn(text: '#', width: 1, align: PosAlign.center),
    const PosColumn(text: 'Item', width: 5),
    const PosColumn(text: 'Qty', width: 1, align: PosAlign.center),
    const PosColumn(text: 'Price', width: 2, align: PosAlign.right),
    const PosColumn(text: 'Total', width: 2, align: PosAlign.right),
  ], bold: true)
  ..divider()
  // Multilingual row with Bangla item description
  ..columns([
    const PosColumn(text: '01', width: 1, align: PosAlign.center),
    const PosColumn(text: 'আরাবিকা কফি বিন (Coffee)', width: 5),
    const PosColumn(text: '2', width: 1, align: PosAlign.center),
    const PosColumn(text: '5.00', width: 2, align: PosAlign.right),
    const PosColumn(text: '10.00', width: 2, align: PosAlign.right),
  ], languageTag: 'bn')
  // Japanese item description
  ..columns([
    const PosColumn(text: '02', width: 1, align: PosAlign.center),
    const PosColumn(text: 'チキンカレー (Curry)', width: 5),
    const PosColumn(text: '1', width: 1, align: PosAlign.center),
    const PosColumn(text: '9.50', width: 2, align: PosAlign.right),
    const PosColumn(text: '9.50', width: 2, align: PosAlign.right),
  ], languageTag: 'ja')
  ..divider()
  ..total('TOTAL', '19.50')
  ..cut();
```

---

## Supported Transports

### 1. WiFi / Network (TCP Port 9100)
Discover and connect to kitchen printers, cashier terminals, or wireless print servers:

```dart
// Auto-discover network printers on the local WiFi subnet
final result = await NetworkTransport.discoverDevices();
// Or: final result = await EscposPrinter.discoverWifi();

for (final device in result.valueOrNull ?? []) {
  print('Found: ${device.name} (${device.model}) at ${device.ip}:${device.port}');
}

// Connect directly using the discovered NetworkDevice
final device = result.valueOrNull!.first;
final printer = EscposPrinter.network(device);

// Or connect manually by IP address
final directPrinter = EscposPrinter.wifi(
  '192.168.1.100',
  port: 9100, // default
  profile: PrinterProfile.generic80, // or generic58
);
await printer.print(receipt);
```

### 2. Bluetooth Classic (SPP / Android)
Connect to portable mobile thermal printers:

```dart
// List paired Bluetooth devices
final result = await BluetoothTransport.listPairedDevices();
final device = result.valueOrNull!.first;

final printer = EscposPrinter.bluetooth(device.address);
await printer.print(receipt);
```

### 3. USB OTG / Direct (Android)
Connect directly with a USB-A to USB-C or OTG cable:

```dart
// Discover connected USB printers
final result = await UsbTransport.listDevices();
final printerDevice = result.valueOrNull!.first;

final printer = EscposPrinter.usb(
  vendorId: printerDevice.vendorId,
  productId: printerDevice.productId,
);
await printer.print(receipt);
```

### 4. Sunmi POS Built-in / Inbuilt Printer (Sunmi D3, V2, T2)
Connect directly to the integrated thermal receipt printer on Sunmi POS hardware terminals. Receipts are executed via Sunmi's native `LineApi` architecture with automatic dashed dividers, vector typography, and full 14-language support:

```dart
// Connect to Sunmi built-in printer (Sunmi D3 80 mm or Sunmi V2 58 mm)
final printer = EscposPrinter.sunmi();
// Or alias: final printer = EscposPrinter.inbuilt();

await printer.print(receipt);
await printer.close();

// Optional: query hardware paper width or trigger cash drawer
final isSunmi = await SunmiTransport.isSunmiDevice();
final paperWidth = await SunmiTransport.getPaperWidth(); // 80 or 58 mm
await SunmiTransport.openDrawer(); // Dual-channel AIDL + ESC/POS kick
```

### 5. Virtual In-Memory (Unit Testing)
Test your receipt layout and command formatting without real hardware:

```dart
final fake = FakeTransport();
final printer = EscposPrinter.custom(fake);

await printer.print(receipt);
print('Encoded ${fake.recordedBytes.length} ESC/POS bytes!');
```

---

## Zero-Waste Developer Tools

### Live On-Screen Preview (`ReceiptPreview`)
Preview your receipt in Flutter UI exactly as it will appear on paper before printing:

```dart
ReceiptPreview(
  receipt: myReceipt,
  profile: PrinterProfile.generic80, // or generic58
)
```

---

## Thermal Label & Sticker Printing (TSPL)

`posprint_kit` provides full support for **TSPL / TSPL2 (TSC Printer Language)** for desktop and portable label printers (TSC, Xprinter, Gprinter, Rongta, etc.) over **USB, WiFi, and Bluetooth**:

### 1-Line Kitchen / Order Token Sticker (`TsplLabel.token`)
Generate standard order/token stickers with zero coordinate math:

```dart
final label = TsplLabel.token(
  tokenNumber: '027',                                    // TOKEN - 027
  date: '11/05/2026',                                    // 11/05/2026
  guest: 'Walk-in',                                      // Guest : Walk-in
  sequence: '2 of 2',                                    // 2 of 2
  item: 'Salcoty SMALL',                                 // Salcoty SMALL
  addons: const ['Sugar Free', 'moglai', 'onion fry'],  // Auto-wrapped with indent
  specialInstructions: 'add more suger, suger free',      // SI : add more suger, suger free
  note: 'test dfef cvvvcdd bbbbb vvg nnnnn cccc mmmm zzz', // Auto-wrapped order notes
  size: TsplSize.size60x40,                              // Dynamic scaling applied!
);

await printer.print(label);
```

> [!TIP]
> **Smart Omission**: If `note`, `specialInstructions`, `addons`, `guest`, or `sequence` are empty or omitted, their labels (`Note:`, `SI :`, `Addon:`) are completely hidden.

### Auto-Flow Layout (Zero Math Required!)
For custom labels, stack elements sequentially without calculating vertical coordinates:

```dart
final label = TsplLabel(size: TsplSize.size60x40)
  ..rowMm(left: 'TOKEN - 027', right: '11/05/2026', font: TsplFont.font3)
  ..rowMm(left: 'Guest : Walk-in', right: '2 of 2', font: TsplFont.font2)
  ..dividerMm()
  ..textLineMm('Salcoty SMALL', font: TsplFont.font3)
  ..wrappedTextMm('Note: Please prepare without nuts or dairy.');
```

### Millimeter-Exact Coordinate Builder
For exact pixel-perfect control over every millimeter:

```dart
import 'package:posprint_kit/posprint_kit.dart';

void main() async {
  // 1. Connect via USB, WiFi, or Bluetooth (strictly for TSPL sticker printers)
  final printer = TsplPrinter.usb(vendorId: 0x0483, productId: 0x5740);
  // or: TsplPrinter.bluetooth('00:11:22:33:44:55');
  // or: TsplPrinter.wifi('192.168.1.100');

  // 2. Build your label sticker directly in physical millimeters!
  final label = TsplLabel(size: TsplSize.size40x30)
    ..boxMm(horizontal: 1.0, vertical: 1.0, endHorizontal: 39.0, endVertical: 29.0, thickness: 2)
    ..textMm('ORGANIC STORE', horizontal: 2.0, vertical: 2.0, font: TsplFont.font3)
    ..lineMm(horizontal: 2.0, vertical: 6.0, width: 36.0, thickness: 1)
    ..textMm('Sourdough Bread', horizontal: 2.0, vertical: 7.5, font: TsplFont.font2)
    ..textRasterMm('টাটকা রুটি', horizontal: 2.0, vertical: 11.0, fontSize: 13.0, languageTag: 'bn')
    ..barcodeMm('20491024', horizontal: 2.0, vertical: 15.0, height: 5.5, narrow: 1, wide: 2)
    ..qrMm('https://posprint.link', horizontal: 28.0, vertical: 15.0, size: 2)
    ..textMm('PRICE: \$4.50', horizontal: 2.0, vertical: 24.5, font: TsplFont.font3)
    ..print(copies: 1);

  // 3. Print!
  await printer.print(label);
  await printer.close();
}
```

### Multi-Size Label Presets & Quick Orientation Swap
`posprint_kit` includes pre-calibrated sizes for both landscape and portrait sticker rolls:
* `TsplSize.size40x30`: 40 × 30 mm (Retail shelf tag)
* `TsplSize.size30x40`: 30 × 40 mm (Portrait price & pharmacy tag)
* `TsplSize.size50x30`: 50 × 30 mm (Storage / asset sticker)
* `TsplSize.size30x50`: 30 × 50 mm (Portrait asset tag)
* `TsplSize.size60x40`: 60 × 40 mm (Shipping / barcode label)
* `TsplSize.size40x60`: 40 × 60 mm (Portrait product barcode)
* `TsplSize.size20x30`: 20 × 30 mm (Jewelry, cable, small tag)
* `TsplSize.size30x20`: 30 × 20 mm (Compact price tag)
* `TsplSize.size70x50`: 70 × 50 mm (Carton box)
* `TsplSize.size80x50`: 80 × 50 mm (Warehouse logistics)
* `TsplSize.size100x150`: 100 × 150 mm (4" × 6" waybill)
* **Quick 90° flip**: `size.flipped` instantly swaps width and height.
* Custom: `TsplSize(widthMm: 45, heightMm: 25, gapMm: 2.0)`

### Live Label Preview (`TsplLabelPreview`)
```dart
TsplLabelPreview(
  label: myLabel,
  maxWidth: 320,
)
```

### Drop-in Connection Picker (`PrinterPicker`)
Allow users to scan, choose, and configure WiFi, Bluetooth, or USB printers with a ready-made dialog:

```dart
PrinterPicker(
  onPrinterSelected: (chosenPrinter) {
    // Save or immediately use chosen printer
  },
)
```

### Environment Doctor (`EscposLink.doctor()`)
Check if Bluetooth, USB host feature, and network permissions are properly configured:

```dart
final report = await EscposLink.doctor();
for (final check in report.checks) {
  print('${check.name}: ${check.passed ? "OK" : check.hint}');
}
```

### Calibration Test Page (`printTestPage`)
Prints an alignment ruler, barcode, QR code, and language test lines:

```dart
await printer.printTestPage();
```

---

## Friendly Error Handling

Public APIs never throw unhandled exceptions. Operations return `Result<T>` with actionable error diagnostics:

```dart
final result = await printer.print(receipt);

if (result.isError) {
  final error = result.errorOrNull!;
  print('What happened: ${error.message}');
  print('How to fix it:  ${error.hint}');
}
```

## Guaranteed 14-Language Support

Most thermal printers have limited built-in Latin code pages and cannot render complex Indic conjuncts, East Asian characters, or Right-to-Left Arabic.

`posprint_kit` automatically detects the script: Latin lines use fast native ESC/POS commands, while complex scripts are rendered into pixel-perfect 1-bit thermal graphics using Flutter's text engine and background isolates.

| Language / Script | ISO Tag | Example Text | Default Thermal Mode |
|---|---|---|---|
| **English / Latin** | `en` | `Burger x2` | Fast native monospace ESC/POS |
| **Bangla (Bengali)** | `bn` | `বার্গার x2, ধন্যবাদ` | Auto 1-bit thermal image (conjuncts joined) |
| **Hindi (Devanagari)** | `hi` | `धन्यवाद, पनीर मसाला` | Auto 1-bit thermal image |
| **Tamil** | `ta` | `நன்றி, மசாலா தோசை` | Auto 1-bit thermal image (`Noto Sans Tamil`) |
| **Telugu** | `te` | `ధన్యవాదాలు` | Auto 1-bit thermal image (`Noto Sans Telugu`) |
| **Arabic** | `ar` | `شكراً لزيارتكم` | Auto 1-bit thermal image (Right-to-Left RTL) |
| **Hebrew** | `he` | `תודה רבה` | Auto 1-bit thermal image (Right-to-Left RTL) |
| **Chinese (Simplified)** | `zh-Hans` | `谢谢惠顾` | Auto 1-bit thermal image / Opt-in native |
| **Chinese (Traditional)** | `zh-Hant` | `謝謝惠顧` | Auto 1-bit thermal image / Opt-in native |
| **Japanese** | `ja` | `ありがとうございます` | Auto 1-bit thermal image (`ja` locale) |
| **Korean (Hangul)** | `ko` | `감사합니다` | Auto 1-bit thermal image |
| **Thai** | `th` | `ขอบคุณครับ` | Auto 1-bit thermal image |
| **German** | `de` | `Großes Schnitzel` | Native code page (CP437 / CP858) |
| **Portuguese** | `pt` | `Não há refeição` | Native code page (CP850 / CP858) |
| **Turkish** | `tr` | `Teşekkürler` | Native code page / auto image |

---


---

## Documentation

* [Quick Start Guide](doc/quickstart.md) — 3-line start for WiFi, Bluetooth, and USB.
* [Cookbook & Recipes](doc/cookbook.md) — Multi-column tables, logos, QR codes, and Bangla/Arabic recipes.
* [Troubleshooting Checklist](doc/troubleshooting.md) — Common printer quirks, disconnects, and fixes.
* [Glossary of Terms](doc/glossary.md) — Plain explanations of ESC/POS, rasterization, code pages, and MTU.

---

## Contributing & License

Contributions are welcome! Please ensure all tests pass (`flutter test`) and `flutter analyze` is clean.

Licensed under the [MIT License](LICENSE).
