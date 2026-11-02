# posprint_kit

[![Pub Version](https://img.shields.io/pub/v/posprint_kit)](https://pub.dev/packages/posprint_kit)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)
[![Flutter Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg)](https://flutter.dev)

A beginner-friendly, multi-language Flutter plugin for printing thermal receipts in **ESC/POS** mode over **WiFi, Bluetooth, and USB**, supporting any language (English, Bangla, Arabic, Chinese, Japanese, Korean, Hindi, Tamil, Telugu, and more).

---

## The 3-Line Quick Start

Print a receipt to any ESC/POS thermal printer in about 3 lines without touching raw bytes, code pages, or hex commands:

```dart
import 'package:posprint_kit/posprint_kit.dart';
or 
import 'package:posprint_kit/advanced.dart';

void main() async {
  // 1. Connect to printer (WiFi, Bluetooth, or USB)
  final printer = EscposPrinter.wifi('192.168.1.50');

  // 2. Build your receipt with the fluent API
  final receipt = Receipt()
    ..title('MY RESTAURANT')
    ..row('Burger x2', '12.00')
    ..row('বার্গার x1', '6.00', languageTag: 'bn') // Bangla auto-rendered
    ..divider()
    ..total('TOTAL', '18.00')
    ..cut();

  // 3. Print!
  await printer.print(receipt);
  await printer.close();
}
```

---

## Key Features

* **3-Line Beginner API**: Print immediately without understanding ESC/POS specifications, baud rates, or hex buffers.
* **Guaranteed 14 Languages**: Built-in shaping and automatic 1-bit thermal rasterization for complex Asian, Indic, and Middle Eastern scripts.
* **Multi-Column Tables (`Receipt.columns`)**: Build 3, 4, 5+ column POS receipts (`[#, Item, Qty, Price, Total]`) with customizable flex ratios, alignments, and multi-line wrapping.
* **Unified Transports**: Connect over **WiFi / LAN** (TCP port 9100), **Bluetooth Classic** (Android SPP), and **USB OTG / Direct** with auto-permissions.
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

### 4. Virtual In-Memory (Unit Testing)
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
