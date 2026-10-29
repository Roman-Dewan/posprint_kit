import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posprint_kit/advanced.dart';
import 'package:posprint_kit/posprint_kit.dart';

void main() {
  runApp(const PosPrintKitExampleApp());
}

// OLD:
// class MyApp extends StatefulWidget {
//   const MyApp({super.key});
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
// class _MyAppState extends State<MyApp> {
//   String _platformVersion = 'Unknown';
//   final _posprintKitPlugin = PosprintKit();
//   @override
//   void initState() {
//     super.initState();
//     initPlatformState();
//   }
//   Future<void> initPlatformState() async { ... }
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('Plugin example app')),
//         body: Center(child: Text('Running on: $_platformVersion\n')),
//       ),
//     );
//   }
// }

/// Alias for backwards compatibility with widget tests.
typedef MyApp = PosPrintKitExampleApp;

/// Main example application for testing posprint_kit features.
class PosPrintKitExampleApp extends StatelessWidget {
  const PosPrintKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Print Kit Test App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _platformVersion = 'Loading...';
  PrinterProfile _selectedProfile = PrinterProfile.generic80;

  // Network printer config
  final _hostController = TextEditingController(text: '192.168.1.50');
  final _portController = TextEditingController(text: '9100');

  // Bluetooth printer config & state
  final _btAddressController = TextEditingController(text: '00:11:22:33:44:55');
  List<BluetoothDevice> _pairedBtDevices = [];
  BluetoothDevice? _selectedBtDevice;
  bool _isScanningBt = false;

  // USB printer config & state
  final _usbVidController = TextEditingController(text: '0x04B8');
  final _usbPidController = TextEditingController(text: '0x0202');
  List<UsbDevice> _usbDevices = [];
  UsbDevice? _selectedUsbDevice;
  bool _isScanningUsb = false;

  // Diagnostics & Status
  String? _statusMessage;
  bool _isSuccess = true;
  bool _isLoading = false;
  DoctorReport? _doctorReport;

  // In-memory test output
  Uint8List? _lastRecordedBytes;
  int _lastBytesLength = 0;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _btAddressController.dispose();
    _usbVidController.dispose();
    _usbPidController.dispose();
    super.dispose();
  }

  Future<void> _initPlatformState() async {
    String platformVersion;
    try {
      final plugin = PosprintKit();
      platformVersion =
          await plugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Receipt _buildSampleReceipt() {
    return Receipt()
      ..title('MY RESTAURANT')
      ..text('Order #1042 • Dine-in • Table 4', align: PosAlign.center)
      ..divider()
      ..row('Burger x2 (w/ cheese)', '12.00')
      ..row('বার্গার x1 (চিজি)', '6.00', languageTag: 'bn')
      ..row('チキンカレー x1', '9.00', languageTag: 'ja')
      ..row('招牌牛肉面 x1', '14.50', languageTag: 'zh-Hans')
      ..row('وجبة شاورما x1', '8.50', languageTag: 'ar')
      ..divider()
      ..total('TOTAL', '50.00')
      ..feed(1)
      ..qr('https://github.com/posprint_kit/order/1042', size: 6)
      ..barcode('10429812', type: BarcodeType.code128)
      ..feed(2)
      ..cut();
  }

  Future<void> _runVirtualPrintTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Encoding receipt into ESC/POS bytes...';
      _isSuccess = true;
    });

    final fakeTransport = FakeTransport();
    final printer = EscposPrinter.custom(
      fakeTransport,
      profile: _selectedProfile,
      rasterizer: FlutterTextRasterizer(),
    );

    final stopwatch = Stopwatch()..start();
    final receipt = _buildSampleReceipt();
    final result = await printer.print(receipt);
    stopwatch.stop();

    await printer.close();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isOk) {
        _isSuccess = true;
        _lastRecordedBytes = fakeTransport.recordedBytes;
        _lastBytesLength = fakeTransport.recordedBytes.length;
        _statusMessage =
            'Virtual print test succeeded in ${stopwatch.elapsedMilliseconds} ms!\n'
            'Generated $_lastBytesLength bytes across ${fakeTransport.writtenChunks.length} chunks.';
      } else {
        _isSuccess = false;
        final err = result.errorOrNull!;
        _statusMessage = 'Virtual print failed: ${err.message}\nHint: ${err.hint}';
      }
    });
  }

  Future<void> _printToWiFiPrinter({bool testPageOnly = false}) async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a printer IP address.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to WiFi printer at $host:$port...';
      _isSuccess = true;
    });

    final printer = EscposPrinter.wifi(
      host,
      port: port,
      profile: _selectedProfile,
      rasterizer: FlutterTextRasterizer(),
    );

    try {
      final Result<void> result;
      if (testPageOnly) {
        result = await printer.printTestPage();
      } else {
        result = await printer.print(_buildSampleReceipt());
      }
      await printer.close();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result.isOk) {
          _isSuccess = true;
          _statusMessage = 'Receipt printed successfully to $host:$port!';
        } else {
          _isSuccess = false;
          final err = result.errorOrNull!;
          _statusMessage = 'Print failed: ${err.message}\n\nHint: ${err.hint}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Unexpected error: $e';
      });
    }
  }

  Future<void> _refreshBluetoothDevices() async {
    setState(() {
      _isScanningBt = true;
      _statusMessage = 'Scanning paired Bluetooth devices...';
      _isSuccess = true;
    });

    var res = await BluetoothTransport.listPairedDevices();

    // On Android 12+ (API 31+), if permission denied, prompt for runtime permission
    if (res.isError &&
        res.errorOrNull?.code == PrinterErrorCode.permissionDenied) {
      final permRes = await BluetoothTransport.requestPermission();
      if (permRes.isOk && (permRes.valueOrNull ?? false)) {
        res = await BluetoothTransport.listPairedDevices();
      }
    }

    if (!mounted) return;
    setState(() {
      _isScanningBt = false;
      if (res.isOk) {
        _pairedBtDevices = res.valueOrNull ?? [];
        _isSuccess = true;
        if (_pairedBtDevices.isNotEmpty) {
          _statusMessage = 'Found ${_pairedBtDevices.length} paired Bluetooth device(s).';
          if (_selectedBtDevice == null) {
            _selectBluetoothDevice(_pairedBtDevices.first);
          }
        } else {
          _statusMessage =
              'No paired Bluetooth devices found.\nPlease pair your thermal printer in Android Bluetooth Settings first.';
        }
      } else {
        _isSuccess = false;
        final err = res.errorOrNull!;
        _statusMessage =
            'Failed to list Bluetooth devices: ${err.message}\nHint: ${err.hint}';
      }
    });
  }

  Future<void> _requestBluetoothPermission() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting Bluetooth permission...';
      _isSuccess = true;
    });

    final res = await BluetoothTransport.requestPermission();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.isOk && (res.valueOrNull ?? false)) {
        _isSuccess = true;
        _statusMessage = 'Bluetooth permission granted!';
      } else {
        _isSuccess = false;
        final err = res.errorOrNull;
        _statusMessage = err != null
            ? 'Bluetooth permission error: ${err.message}\nHint: ${err.hint}'
            : 'Bluetooth permission was denied by user.';
      }
    });

    await _refreshBluetoothDevices();
  }

  void _selectBluetoothDevice(BluetoothDevice device) {
    setState(() {
      _selectedBtDevice = device;
      _btAddressController.text = device.address;
    });
  }

  Future<void> _printToBluetoothPrinter({bool testPageOnly = false}) async {
    final address = _btAddressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a Bluetooth MAC address.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to Bluetooth device ($address)...';
      _isSuccess = true;
    });

    final printer = EscposPrinter.bluetooth(
      address,
      profile: _selectedProfile,
      rasterizer: FlutterTextRasterizer(),
    );

    try {
      final Result<void> result;
      if (testPageOnly) {
        result = await printer.printTestPage();
      } else {
        result = await printer.print(_buildSampleReceipt());
      }
      await printer.close();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result.isOk) {
          _isSuccess = true;
          _statusMessage = 'Receipt printed successfully via Bluetooth to $address!';
        } else {
          _isSuccess = false;
          final err = result.errorOrNull!;
          _statusMessage =
              'Bluetooth print failed: ${err.message}\n\nHint: ${err.hint}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Unexpected Bluetooth error: $e';
      });
    }
  }

  Future<void> _refreshUsbDevices() async {
    setState(() {
      _isScanningUsb = true;
      _statusMessage = 'Scanning connected USB devices...';
      _isSuccess = true;
    });

    final res = await UsbTransport.listDevices();

    if (!mounted) return;
    setState(() {
      _isScanningUsb = false;
      if (res.isOk) {
        _usbDevices = res.valueOrNull ?? [];
        _isSuccess = true;
        if (_usbDevices.isNotEmpty) {
          _statusMessage = 'Found ${_usbDevices.length} USB device(s).';
          if (_selectedUsbDevice == null) {
            _selectUsbDevice(_usbDevices.first);
          } else {
            for (final d in _usbDevices) {
              if (d.vendorId == _selectedUsbDevice!.vendorId &&
                  d.productId == _selectedUsbDevice!.productId) {
                _selectedUsbDevice = d;
                break;
              }
            }
          }
        } else {
          _statusMessage =
              'No USB devices detected.\nMake sure printer is plugged in via USB OTG cable and powered on.';
        }
      } else {
        _isSuccess = false;
        final err = res.errorOrNull!;
        _statusMessage =
            'Failed to list USB devices: ${err.message}\nHint: ${err.hint}';
      }
    });
  }

  void _selectUsbDevice(UsbDevice device) {
    setState(() {
      _selectedUsbDevice = device;
      _usbVidController.text =
          '0x${device.vendorId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
      _usbPidController.text =
          '0x${device.productId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    });
  }

  int _parseUsbId(String text, int defaultVal) {
    final clean = text.trim();
    if (clean.toLowerCase().startsWith('0x')) {
      return int.tryParse(clean.substring(2), radix: 16) ?? defaultVal;
    }
    return int.tryParse(clean) ?? defaultVal;
  }

  Future<void> _requestUsbPermission([UsbDevice? targetDevice]) async {
    final vid = targetDevice?.vendorId ?? _parseUsbId(_usbVidController.text, 0x04b8);
    final pid = targetDevice?.productId ?? _parseUsbId(_usbPidController.text, 0x0202);

    setState(() {
      _isLoading = true;
      _statusMessage =
          'Requesting USB permission for VID 0x${vid.toRadixString(16)} PID 0x${pid.toRadixString(16)}...';
      _isSuccess = true;
    });

    final res = await UsbTransport.requestPermission(vid, pid);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.isOk && (res.valueOrNull ?? false)) {
        _isSuccess = true;
        _statusMessage = 'USB permission granted!';
      } else {
        _isSuccess = false;
        final err = res.errorOrNull;
        _statusMessage = err != null
            ? 'USB permission error: ${err.message}\nHint: ${err.hint}'
            : 'USB permission was denied by user.';
      }
    });

    await _refreshUsbDevices();
  }

  Future<void> _printToUsbPrinter({bool testPageOnly = false}) async {
    final vid = _parseUsbId(_usbVidController.text, 0x04b8);
    final pid = _parseUsbId(_usbPidController.text, 0x0202);

    // If permission has not been granted yet, request it automatically
    final isPermitted = _selectedUsbDevice?.hasPermission ?? false;
    if (!isPermitted) {
      setState(() {
        _isLoading = true;
        _statusMessage =
            'Requesting USB permission for printer (VID: 0x${vid.toRadixString(16)}, PID: 0x${pid.toRadixString(16)})...';
        _isSuccess = true;
      });

      final permRes = await UsbTransport.requestPermission(vid, pid);
      if (permRes.isError || (permRes.valueOrNull != true)) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _statusMessage =
              'USB permission was denied by user. Please accept the prompt on your Android screen.';
        });
        return;
      }
      await _refreshUsbDevices();
    }

    setState(() {
      _isLoading = true;
      _statusMessage =
          'Connecting to USB printer (VID: 0x${vid.toRadixString(16)}, PID: 0x${pid.toRadixString(16)})...';
      _isSuccess = true;
    });

    final printer = EscposPrinter.usb(
      vendorId: vid,
      productId: pid,
      profile: _selectedProfile,
      rasterizer: FlutterTextRasterizer(),
    );

    try {
      final Result<void> result;
      if (testPageOnly) {
        result = await printer.printTestPage();
      } else {
        result = await printer.print(_buildSampleReceipt());
      }
      await printer.close();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result.isOk) {
          _isSuccess = true;
          _statusMessage = 'Receipt printed successfully via USB!';
        } else {
          _isSuccess = false;
          final err = result.errorOrNull!;
          _statusMessage =
              'USB print failed: ${err.message}\n\nHint: ${err.hint}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Unexpected USB error: $e';
      });
    }
  }

  Future<void> _runDoctorCheck() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Running diagnostics...';
    });

    final report = await EscposLink.doctor();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _doctorReport = report;
      _statusMessage = 'Diagnostics finished.';
      _isSuccess = !report.hasErrors;
    });
  }

  void _showPrinterPickerDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: PrinterPicker(
              initialProfile: _selectedProfile,
              onPrinterSelected: (chosenPrinter) {
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selected printer: ${chosenPrinter.profile.dotsWidth} dots wide.',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Print Kit Test Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Open Printer Picker',
            onPressed: _showPrinterPickerDialog,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildPreviewTab(),
          _buildWiFiPrintTab(),
          _buildBluetoothPrintTab(),
          _buildUsbPrintTab(),
          _buildVirtualTestTab(),
          _buildDoctorTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt),
            label: 'Preview',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi),
            label: 'WiFi Print',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            label: 'Bluetooth',
          ),
          NavigationDestination(
            icon: Icon(Icons.usb),
            label: 'USB',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory),
            label: 'Virtual Test',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            label: 'Doctor',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Paper Profile:'),
                  const SizedBox(height: 8.0),
                  SegmentedButton<PrinterProfile>(
                    segments: const [
                      ButtonSegment(
                        value: PrinterProfile.generic80,
                        label: Text('80 mm (576 dots)'),
                      ),
                      ButtonSegment(
                        value: PrinterProfile.generic58,
                        label: Text('58 mm (384 dots)'),
                      ),
                    ],
                    selected: {_selectedProfile},
                    onSelectionChanged: (set) {
                      setState(() => _selectedProfile = set.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Center(
            child: Text(
              'Live Receipt Preview (Bangla, Chinese, Japanese, Arabic, English)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8.0),
          ReceiptPreview(
            receipt: _buildSampleReceipt(),
            profile: _selectedProfile,
          ),
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }

  Widget _buildWiFiPrintTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Direct WiFi / LAN Printing',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6.0),
          const Text(
            'Connects directly to an ESC/POS receipt printer on your local network over TCP port 9100.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Printer IP Address',
              hintText: '192.168.1.50',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lan),
            ),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 12.0),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Port (default 9100)',
              hintText: '9100',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _printToWiFiPrinter(),
            icon: _isLoading
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Icon(Icons.print),
            label: const Text('Print Sample Multi-Language Receipt'),
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed:
                _isLoading ? null : () => _printToWiFiPrinter(testPageOnly: true),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Print Diagnostic Test Page (Ruler & Languages)'),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothPrintTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bluetooth Thermal Printing (SPP)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6.0),
          const Text(
            'Connects to paired ESC/POS thermal printers over Bluetooth Classic (RFCOMM SPP).',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16.0),
          FilledButton.tonalIcon(
            onPressed: _isScanningBt ? null : _refreshBluetoothDevices,
            icon: _isScanningBt
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Icon(Icons.bluetooth_searching),
            label: const Text('Scan Paired Bluetooth Devices'),
          ),
          const SizedBox(height: 8.0),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _requestBluetoothPermission,
            icon: const Icon(Icons.security),
            label: const Text('Request Bluetooth Permission (Android 12+)'),
          ),
          const SizedBox(height: 12.0),
          // OLD:
          // if (_pairedBtDevices.isNotEmpty) ...[
          //   Text(
          //     'Paired Devices (${_pairedBtDevices.length})',
          //     style: Theme.of(context).textTheme.titleSmall,
          //   ),
          //   const SizedBox(height: 6.0),
          //   for (final d in _pairedBtDevices)
          //     Card( ... ),
          //   const SizedBox(height: 12.0),
          // ],
          DropdownButtonFormField<BluetoothDevice>(
            initialValue: _pairedBtDevices.contains(_selectedBtDevice)
                ? _selectedBtDevice
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Paired Bluetooth Device',
              hintText: 'Choose from paired printers',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.bluetooth_connected),
            ),
            items: _pairedBtDevices.map((d) {
              final displayName =
                  d.name.isNotEmpty ? d.name : 'Unknown Device';
              return DropdownMenuItem<BluetoothDevice>(
                value: d,
                child: Text(
                  '$displayName (${d.address})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (chosen) {
              if (chosen != null) {
                _selectBluetoothDevice(chosen);
              }
            },
          ),
          const SizedBox(height: 12.0),
          TextField(
            controller: _btAddressController,
            decoration: const InputDecoration(
              labelText: 'Bluetooth MAC Address',
              hintText: '00:11:22:33:44:55',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
              helperText:
                  'Auto-filled when selecting a device from the dropdown above, or enter manually',
            ),
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _printToBluetoothPrinter(),
            icon: _isLoading
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Icon(Icons.print),
            label: const Text('Print Sample Multi-Language Receipt'),
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () => _printToBluetoothPrinter(testPageOnly: true),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Print Diagnostic Test Page (Ruler & Languages)'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsbPrintTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'USB Thermal Printing (OTG / Direct)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6.0),
          const Text(
            'Connects directly to ESC/POS thermal printers via USB cable or USB OTG adapter.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16.0),
          FilledButton.tonalIcon(
            onPressed: _isScanningUsb ? null : _refreshUsbDevices,
            icon: _isScanningUsb
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Icon(Icons.usb),
            label: const Text('Scan Connected USB Devices'),
          ),
          const SizedBox(height: 12.0),
          if (_usbDevices.isNotEmpty) ...[
            Text(
              'Connected USB Devices (${_usbDevices.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6.0),
            for (final d in _usbDevices)
              Card(
                elevation: (_selectedUsbDevice?.vendorId == d.vendorId &&
                        _selectedUsbDevice?.productId == d.productId)
                    ? 3
                    : 1,
                color: (_selectedUsbDevice?.vendorId == d.vendorId &&
                        _selectedUsbDevice?.productId == d.productId)
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  leading: const Icon(Icons.usb),
                  title: Text(d.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VID: 0x${d.vendorId.toRadixString(16).padLeft(4, '0').toUpperCase()} (${d.vendorId})  '
                        'PID: 0x${d.productId.toRadixString(16).padLeft(4, '0').toUpperCase()} (${d.productId})',
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        d.hasPermission
                            ? '✓ Permission Granted'
                            : '⚠ Permission Required',
                        style: TextStyle(
                          color:
                              d.hasPermission ? Colors.green : Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                  trailing: (!d.hasPermission)
                      ? ElevatedButton(
                          onPressed: () => _requestUsbPermission(d),
                          child: const Text('Grant Perm'),
                        )
                      : const Text('Select'),
                  onTap: () => _selectUsbDevice(d),
                ),
              ),
            const SizedBox(height: 12.0),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usbVidController,
                  decoration: const InputDecoration(
                    labelText: 'Vendor ID (VID)',
                    hintText: '0x04B8 or 1208',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.usb),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: TextField(
                  controller: _usbPidController,
                  decoration: const InputDecoration(
                    labelText: 'Product ID (PID)',
                    hintText: '0x0202 or 514',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.memory),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _requestUsbPermission(),
            icon: const Icon(Icons.security),
            label: const Text('Request USB Permission for VID/PID'),
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _printToUsbPrinter(),
            icon: _isLoading
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Icon(Icons.print),
            label: const Text('Print Sample Multi-Language Receipt'),
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed:
                _isLoading ? null : () => _printToUsbPrinter(testPageOnly: true),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Print Diagnostic Test Page (Ruler & Languages)'),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'In-Memory Virtual Print Test (FakeTransport)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6.0),
          const Text(
            'Test the complete encoding pipeline (shaping, 1-bit rasterization, command formatting) '
            'without requiring physical thermal hardware.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : _runVirtualPrintTest,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run Virtual Print Test'),
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
          if (_lastRecordedBytes != null) ...[
            const SizedBox(height: 16.0),
            Text(
              'Recorded Byte Stream Inspector',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _hexDumpPreview(_lastRecordedBytes!),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.0,
                  color: Colors.lightGreenAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoctorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Environment & Permissions Doctor',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _isLoading ? null : _runDoctorCheck,
                icon: const Icon(Icons.refresh),
                label: const Text('Check'),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            'OS: $_platformVersion',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16.0),
          if (_doctorReport != null) ...[
            for (final check in _doctorReport!.checks)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                color: check.passed ? Colors.green.shade50 : Colors.red.shade50,
                child: ListTile(
                  leading: Icon(
                    check.passed ? Icons.check_circle : Icons.error,
                    color: check.passed ? Colors.green : Colors.red,
                  ),
                  title: Text(check.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(check.message),
                      if (check.hint != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Hint: ${check.hint}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Tap "Check" to run EscposLink.doctor().'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_statusMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: _isSuccess ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isSuccess ? Icons.check_circle_outline : Icons.info_outline,
            color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                fontSize: 13.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _hexDumpPreview(Uint8List bytes) {
    final buffer = StringBuffer();
    final take = bytes.length.clamp(0, 160);
    for (var i = 0; i < take; i += 16) {
      final lineBytes = bytes.sublist(i, (i + 16).clamp(0, take));
      final hex = lineBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      final asciiChars = lineBytes
          .map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.')
          .join();
      buffer.writeln('${hex.padRight(48)} | $asciiChars');
    }
    if (bytes.length > take) {
      buffer.writeln('... (${bytes.length - take} more bytes)');
    }
    return buffer.toString();
  }
}
