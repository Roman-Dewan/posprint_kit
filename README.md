# posprint_kit
A beginner-friendly, multi-language Flutter plugin for printing thermal receipts in **ESC/POS** mode over **WiFi, Bluetooth, and USB**, supporting any language (English, Bangla, Chinese, Japanese, Korean, Arabic, Hindi, Thai, and more).

---

## 3-Line Quick Start

Print a receipt over WiFi to any standard thermal receipt printer in 3 lines:

```dart
import 'package:posprint_kit/posprint_kit.dart';

void main() async {
  final printer = EscposPrinter.wifi('192.168.1.50');
  await printer.print(
    Receipt()
      ..title('MY RESTAURANT')
      ..row('Burger x2', '12.00')
      ..row('বার্গার x1', '6.00') // Bangla
      ..row('チキンカレー x1', '9.00', languageTag: 'ja') // Japanese
      ..divider()
      ..total('TOTAL', '27.00')
      ..cut(),
  );
  await printer.close();
}
```

---

## Multi-Language Support

Most thermal printers have limited built-in code pages and cannot print Asian or complex script conjuncts directly. `posprint_kit` automatically decides whether to send fast native text or render the line into high-resolution 1-bit thermal graphics via Flutter's text engine.

| Script / Language | Example | Default Mode | Alignment |
|---|---|---|---|
| Latin (English, Spanish, French) | `Burger $12.00` | Native text | Left / Right |
| Accented Latin (CP437, CP858, CP1252) | `Café crème brûlée 8,50 €` | Native code page | Left / Right |
| **Bangla** | `বার্গার x2, ধন্যবাদ` | Auto image (conjuncts joined) | Pixel-accurate row |
| **Hindi (Devanagari)** | `धन्यवाद, पनीर मसाला` | Auto image | Pixel-accurate row |
| **Chinese (Simplified / Traditional)** | `谢谢惠顾 / 謝謝惠顧` | Auto image / Opt-in native | Pixel-accurate row |
| **Japanese (Kanji + Kana)** | `ありがとうございます` | Auto image (`ja` locale) | Pixel-accurate row |
| **Korean (Hangul)** | `감사합니다` | Auto image | Pixel-accurate row |
| **Arabic / Hebrew** | `شكراً لزيارتكم` | Auto image (RTL) | Right-to-Left |
| **Thai** | `ขอบคุณครับ` | Auto image | Pixel-accurate row |

---

<!-- OLD:
## Key Features

1. **The 3-Line API**: Designed so junior developers can connect and print immediately without learning ESC/POS or byte commands.
2. **Friendly Errors**: Every `PrinterError` provides a clear `message` (what happened) and a `hint` (how to fix it).
3. **Queue & Automatic Retry**: Print jobs are executed strictly sequentially without interleaving bytes, and retry transient network dropouts with backoff.
4. **On-Screen Preview (`ReceiptPreview`)**: Visualize receipts in Flutter widgets without wasting paper.
5. **Setup Diagnostics (`EscposLink.doctor()`)**: Built-in verification utility similar to `flutter doctor` that checks network, OS permissions, and capabilities.
6. **Drop-in Printer Picker (`PrinterPicker`)**: Ready-made modal/dialog widget for scanning, configuring, and testing printers.
-->

## Key Features

* **Unified Transports**: WiFi / LAN (port 9100), Bluetooth Classic (SPP), and USB OTG (with auto-permission handling).
* **Multi-Language Engine**: Native Latin text; automatic 1-bit thermal rasterization for Bangla, Arabic (RTL), CJK, Hindi, and Thai.
* **The 3-Line API**: Simple fluent builder (`Receipt`) without low-level ESC/POS byte commands.
* **FIFO Queue & Retry**: Non-interleaving print queue with automatic exponential backoff retry.
* **Friendly Errors**: Returns `Result<T>` with actionable `message` and troubleshooting `hint`.
* **Zero-Waste Tools**: On-screen `ReceiptPreview` widget and `EscposLink.doctor()` diagnostics utility.

---

## Documentation

- [Quick Start Guide](doc/quickstart.md)
- [Cookbook & Recipes](doc/cookbook.md)
- [Troubleshooting Checklist](doc/troubleshooting.md)
- [Glossary of Terms](doc/glossary.md)
