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
    show
        BarcodeType,
        ColumnsOp,
        PosAlign,
        PosColumn,
        QrErrorCorrectionLevel,
        TextMode,
        TextSize;
export 'src/core/printer_profile.dart' show PrinterProfile;
export 'src/core/receipt.dart' show Receipt;
export 'src/core/result.dart'
    show Err, Ok, PrinterError, PrinterErrorCode, Result;
export 'src/discovery/printer_discovery.dart'
    show NetworkDevice, NetworkDiscovery;
export 'src/doctor/doctor.dart' show DoctorCheck, DoctorReport;
export 'src/printer.dart'
    show EscposLink, EscposPrinter, PosPrintKit, Transport;
export 'src/rendering/receipt_preview.dart' show ReceiptPreview;
export 'src/transports/bluetooth_transport.dart'
    show BluetoothDevice, BluetoothTransport;
export 'src/transports/network_transport.dart' show NetworkTransport;
export 'src/transports/sunmi_transport.dart'
    show InbuiltTransport, SunmiTransport;
export 'src/transports/usb_transport.dart' show UsbDevice, UsbTransport;
export 'src/tspl/tspl_encoder.dart' show TsplEncoder;
export 'src/tspl/tspl_enums.dart'
    show
        TsplBarcodeType,
        TsplBitmapMode,
        TsplDirection,
        TsplFont,
        TsplHumanReadable,
        TsplQrEcc,
        TsplRotation;
export 'src/tspl/tspl_label.dart' show TsplLabel;
export 'src/tspl/tspl_ops.dart'
    show
        TsplBarOp,
        TsplBarcodeOp,
        TsplBitmapOp,
        TsplBoxOp,
        TsplOp,
        TsplQrOp,
        TsplRasterTextOp,
        TsplReverseOp,
        TsplTextOp;
export 'src/tspl/tspl_printer.dart' show TsplPrinter;
export 'src/tspl/tspl_size.dart' show TsplSize;
export 'src/rendering/tspl_label_preview.dart' show TsplLabelPreview;
export 'src/ui/printer_picker.dart' show PrinterPicker;

import 'posprint_kit_platform_interface.dart';

/// Legacy platform interface wrapper.
class PosprintKit {
  /// Queries platform version.
  Future<String?> getPlatformVersion() {
    return PosprintKitPlatform.instance.getPlatformVersion();
  }
}
