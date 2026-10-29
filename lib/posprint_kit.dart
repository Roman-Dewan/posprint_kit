/// A beginner-friendly, multi-language Flutter plugin for thermal receipt printing
/// in ESC/POS mode over WiFi, Bluetooth, and USB.
///
/// Designed to print in about 3 lines:
/// ```dart
/// final printer = EscposPrinter.wifi('192.168.1.50');
/// await printer.print(
///   Receipt()
///     ..title('MY RESTAURANT')
///     ..row('Burger x2', '12.00')
///     ..row('বার্গার x1', '6.00')
///     ..cut(),
/// );
/// await printer.close();
/// ```
library;

export 'src/core/logger.dart' show LogLevel;
export 'src/core/ops.dart'
    show BarcodeType, PosAlign, QrErrorCorrectionLevel, TextMode, TextSize;
export 'src/core/printer_profile.dart' show PrinterProfile;
export 'src/core/receipt.dart' show Receipt;
export 'src/core/result.dart'
    show Err, Ok, PrinterError, PrinterErrorCode, Result;
export 'src/doctor/doctor.dart' show DoctorCheck, DoctorReport;
export 'src/printer.dart'
    show EscposLink, EscposPrinter, PosPrintKit, Transport;
export 'src/rendering/receipt_preview.dart' show ReceiptPreview;
export 'src/transports/bluetooth_transport.dart' show BluetoothDevice;
export 'src/transports/usb_transport.dart' show UsbDevice;
export 'src/ui/printer_picker.dart' show PrinterPicker;

// OLD:
// import 'posprint_kit_platform_interface.dart';
// class PosprintKit {
//   Future<String?> getPlatformVersion() {
//     return PosprintKitPlatform.instance.getPlatformVersion();
//   }
// }

import 'posprint_kit_platform_interface.dart';

/// Legacy platform interface wrapper.
class PosprintKit {
  /// Queries platform version.
  Future<String?> getPlatformVersion() {
    return PosprintKitPlatform.instance.getPlatformVersion();
  }
}
