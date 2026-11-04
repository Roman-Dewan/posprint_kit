import 'package:flutter/material.dart';
import 'package:posprint_kit/advanced.dart';

void main() {
  runApp(const PosPrintKitExampleApp());
}

/// Alias for backwards compatibility with existing widget tests.
typedef MyApp = PosPrintKitExampleApp;

/// A simple, beginner-friendly demo app showing how to use `posprint_kit`
/// to print thermal receipts over WiFi, Bluetooth, and USB in any language.
class PosPrintKitExampleApp extends StatelessWidget {
  const PosPrintKitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Print Kit Test Code',
      debugShowCheckedModeBanner: false,
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
  PrinterProfile _selectedProfile = PrinterProfile.generic80;
  bool _use5ColumnReceipt = false;

  // Connection inputs
  final _hostController = TextEditingController(text: '192.168.0.101');
  final _portController = TextEditingController(text: '9100');
  final _btAddressController = TextEditingController(text: '1C:1A:1B:CE:47:09');
  final _usbVidController = TextEditingController(text: '0x324F');
  final _usbPidController = TextEditingController(text: '0x00D2');

  // Discovered devices & doctor report
  List<BluetoothDevice> _pairedBtDevices = [];
  BluetoothDevice? _selectedBtDevice;
  List<UsbDevice> _usbDevices = [];
  UsbDevice? _selectedUsbDevice;
  List<NetworkDevice> _discoveredNetworkDevices = [];
  NetworkDevice? _selectedNetworkDevice;
  DoctorReport? _doctorReport;

  // TSPL Label state
  TsplSize _selectedTsplSize = TsplSize.size40x30;
  Transport _selectedTsplTransport = Transport.usb;
  int _selectedTsplTemplate = 0;
  TsplDirection _selectedTsplDirection = TsplDirection.normal;

  // Status & loading indicators
  String? _statusMessage;
  bool _isSuccess = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSunmiPaperWidth();
  }

  Future<void> _checkSunmiPaperWidth() async {
    try {
      final isSunmi = await SunmiTransport.isSunmiDevice();
      if (isSunmi) {
        final width = await SunmiTransport.getPaperWidth();
        if (mounted) {
          setState(() {
            _selectedProfile = width <= 58
                ? PrinterProfile.sunmi58
                : PrinterProfile.sunmi80;
          });
        }
      }
    } catch (_) {}
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

  // ---------------------------------------------------------------------------
  // RECEIPT BUILDERS: Clean examples of how to format receipts
  // ---------------------------------------------------------------------------

  /// Example 1: Standard 2-column receipt with multi-language support.
  Receipt _buildSampleReceipt() {
    return Receipt()
      ..title('MY RESTAURANT')
      ..text('Table 4 • Dine-in • Order #1042', align: PosAlign.center)
      ..divider()
      // English (native monospace text)
      ..row('Burger x2 (w/ cheese)', '12.00')
      // Bangla (auto-rendered as high-res 1-bit thermal image with joined conjuncts)
      ..row('বার্গার x1 (চিজি)', '6.00', languageTag: 'bn')
      // Japanese Kanji + Kana
      ..row('チキンカレー x1', '9.00', languageTag: 'ja')
      // Simplified Chinese
      ..row('招牌牛肉面 x1', '14.50', languageTag: 'zh-Hans')
      // Arabic (auto-rendered Right-to-Left)
      ..row('وجبة شاورما x1', '8.50', languageTag: 'ar')
      ..divider()
      ..total('TOTAL', '50.00')
      ..feed(1)
      ..qr('https://github.com/roman-dewan/posprint_kit', size: 6)
      ..barcode('10429812', type: BarcodeType.code128)
      ..feed(2)
      ..drawer()
      ..cut();
  }

  /// Example 2: 5-column restaurant table layout using [Receipt.columns].
  /// Shows flex ratios [1, 5, 1, 2, 2], column alignments, and text auto-wrapping.
  Receipt _build5ColumnOrderReceipt() {
    return Receipt()
      ..title('5-COLUMN BISTRO ORDER')
      ..text('Order #1042 • 5-Column POS Format', align: PosAlign.center)
      ..divider()
      ..columns([
        const PosColumn(text: '#', width: 1, align: PosAlign.center),
        const PosColumn(text: 'Item', width: 5),
        const PosColumn(text: 'Qty', width: 1, align: PosAlign.center),
        const PosColumn(text: 'Price', width: 2, align: PosAlign.right),
        const PosColumn(text: 'Total', width: 2, align: PosAlign.right),
      ], bold: true)
      ..divider()
      ..columns([
        const PosColumn(text: '01', width: 1, align: PosAlign.center),
        const PosColumn(text: 'আরাবিকা কফি বিন (Coffee)', width: 5),
        const PosColumn(text: '50', width: 1, align: PosAlign.center),
        const PosColumn(text: '100.00', width: 2, align: PosAlign.right),
        const PosColumn(text: '5000.00', width: 2, align: PosAlign.right),
      ], languageTag: 'bn')
      ..columns([
        const PosColumn(text: '02', width: 1, align: PosAlign.center),
        const PosColumn(text: 'チキンカレー (Chicken Curry)', width: 5),
        const PosColumn(text: '81', width: 1, align: PosAlign.center),
        const PosColumn(text: '9.50', width: 2, align: PosAlign.right),
        const PosColumn(text: '12000.00', width: 2, align: PosAlign.right),
      ], languageTag: 'ja')
      ..columns([
        const PosColumn(text: '03', width: 1, align: PosAlign.center),
        const PosColumn(text: 'Fresh Lemon Mint Iced Tea', width: 5),
        const PosColumn(text: '3', width: 1, align: PosAlign.center),
        const PosColumn(text: '3.00', width: 2, align: PosAlign.right),
        const PosColumn(text: '9.00', width: 2, align: PosAlign.right),
      ])
      ..divider()
      ..total('TOTAL', '54.50')
      ..feed(1)
      ..qr('https://github.com/roman-dewan/posprint_kit', size: 6)
      ..barcode('123412', width: 40)
      ..feed(2)
      ..cut();
  }

  Receipt _getActiveReceipt() =>
      _use5ColumnReceipt ? _build5ColumnOrderReceipt() : _buildSampleReceipt();

  // ---------------------------------------------------------------------------
  // PRINT EXECUTION HELPER: Clean 3-step printing flow
  // ---------------------------------------------------------------------------

  Future<void> _executePrint(
    String targetLabel,
    EscposPrinter printer, {
    bool testPageOnly = false,
  }) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending print job to $targetLabel...';
      _isSuccess = true;
    });

    try {
      final Result<void> result;
      if (testPageOnly) {
        // Prints calibration ruler and all supported language sample lines
        result = await printer.printTestPage();
      } else {
        // Prints the active receipt
        result = await printer.print(_getActiveReceipt());
      }
      await printer.close();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (result.isOk) {
          _isSuccess = true;
          _statusMessage = 'Success! Receipt printed cleanly to $targetLabel.';
        } else {
          _isSuccess = false;
          final err = result.errorOrNull!;
          _statusMessage = 'Print Error: ${err.message}\nHint: ${err.hint}';
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

  // ---------------------------------------------------------------------------
  // ACTION HANDLERS
  // ---------------------------------------------------------------------------

  Future<void> _printWiFi({bool testPageOnly = false}) async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;
    if (host.isEmpty) {
      _setStatus('Please enter an IP address.', success: false);
      return;
    }

    final printer = EscposPrinter.wifi(
      host,
      port: port,
      profile: _selectedProfile,
      rasterizer: FlutterTextRasterizer(),
    );
    await _executePrint(
      'WiFi ($host:$port)',
      printer,
      testPageOnly: testPageOnly,
    );
  }

  Future<void> _scanNetworkPrinters() async {
    setState(() {
      _isLoading = true;
      _statusMessage =
          'Scanning local network for ESC/POS printers on port 9100...';
      _isSuccess = true;
    });

    final res = await NetworkTransport.discoverDevices();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.isOk) {
        _discoveredNetworkDevices = res.valueOrNull ?? [];
        if (_discoveredNetworkDevices.isNotEmpty) {
          _isSuccess = true;
          _statusMessage = 'Found ${_discoveredNetworkDevices.length} network printer(s).';
          _selectedNetworkDevice = _discoveredNetworkDevices.first;
          _hostController.text = _selectedNetworkDevice!.ip;
          _portController.text = '${_selectedNetworkDevice!.port}';
        } else {
          _isSuccess = false;
          _statusMessage = 'No network printers found on port 9100.\nMake sure your printer is powered on and connected to this WiFi.';
        }
      } else {
        _isSuccess = false;
        final err = res.errorOrNull!;
        _statusMessage = 'Discovery failed: ${err.message}\nHint: ${err.hint}';
      }
    });
  }

  Future<void> _printBluetooth({bool testPageOnly = false}) async {
    final address = _btAddressController.text.trim();
    if (address.isEmpty) {
      _setStatus(
        'Please select or enter a Bluetooth MAC address.',
        success: false,
      );
      return;
    }

    final printer = EscposPrinter.bluetooth(
      address,
      profile: _selectedProfile,
      rasterizer: FlutterTextRasterizer(),
    );
    await _executePrint(
      'Bluetooth ($address)',
      printer,
      testPageOnly: testPageOnly,
    );
  }

  Future<void> _printUsb({bool testPageOnly = false}) async {
    final vid = _parseId(_usbVidController.text, 0x04b8);
    final pid = _parseId(_usbPidController.text, 0x0202);

    final printer = EscposPrinter.usb(
      vendorId: vid,
      productId: pid,
      profile: _selectedProfile,
      rasterizer: FlutterTextRasterizer(),
    );
    await _executePrint(
      'USB (VID 0x${vid.toRadixString(16)})',
      printer,
      testPageOnly: testPageOnly,
    );
  }

  Future<void> _printSunmi({bool testPageOnly = false}) async {
    final profile = (_selectedProfile == PrinterProfile.generic58 ||
            _selectedProfile == PrinterProfile.sunmi58)
        ? PrinterProfile.sunmi58
        : PrinterProfile.sunmi80;
    final printer = EscposPrinter.sunmi(
      profile: profile,
      rasterizer: FlutterTextRasterizer(),
    );
    await _executePrint(
      'Built-in (Sunmi)',
      printer,
      testPageOnly: testPageOnly,
    );
  }

  Future<void> _openSunmiDrawer() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening cash drawer via Sunmi API...';
      _isSuccess = true;
    });

    final res = await SunmiTransport.openDrawer();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.isOk) {
        _isSuccess = true;
        _statusMessage = 'Cash drawer opened successfully!';
      } else {
        _isSuccess = false;
        _statusMessage = 'Cash drawer failed: ${res.errorOrNull?.message}';
      }
    });
  }

  Future<void> _runVirtualPrintTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Running virtual in-memory print test...';
      _isSuccess = true;
    });

    final fakeTransport = FakeTransport();
    final printer = EscposPrinter.custom(
      fakeTransport,
      profile: _selectedProfile,
      rasterizer: FlutterTextRasterizer(),
    );

    final stopwatch = Stopwatch()..start();
    final result = await printer.print(_getActiveReceipt());
    stopwatch.stop();
    await printer.close();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isOk) {
        _isSuccess = true;
        _statusMessage =
            'Virtual Print Succeeded in ${stopwatch.elapsedMilliseconds} ms!\n'
            'Encoded ${fakeTransport.recordedBytes.length} ESC/POS bytes into memory.';
      } else {
        _isSuccess = false;
        final err = result.errorOrNull!;
        _statusMessage = 'Error: ${err.message}\nHint: ${err.hint}';
      }
    });
  }

  Future<void> _scanBluetooth() async {
    setState(() => _isLoading = true);
    var res = await BluetoothTransport.listPairedDevices();
    if (res.isError &&
        res.errorOrNull?.code == PrinterErrorCode.permissionDenied) {
      final permRes = await BluetoothTransport.requestPermission();
      if (permRes.isOk && (permRes.valueOrNull ?? false)) {
        res = await BluetoothTransport.listPairedDevices();
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.isOk) {
        _pairedBtDevices = res.valueOrNull ?? [];
        _isSuccess = true;
        _statusMessage =
            'Found ${_pairedBtDevices.length} paired Bluetooth device(s).';
        if (_pairedBtDevices.isNotEmpty) {
          _selectedBtDevice = _pairedBtDevices.first;
          _btAddressController.text = _selectedBtDevice!.address;
        }
      } else {
        _isSuccess = false;
        _statusMessage =
            res.errorOrNull?.message ?? 'Failed to list Bluetooth devices.';
      }
    });
  }

  Future<void> _scanUsb() async {
    setState(() => _isLoading = true);
    final res = await UsbTransport.listDevices();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.isOk) {
        _usbDevices = res.valueOrNull ?? [];
        _isSuccess = true;
        _statusMessage = 'Found ${_usbDevices.length} USB device(s).';
        if (_usbDevices.isNotEmpty) {
          final first = _usbDevices.first;
          _usbVidController.text =
              '0x${first.vendorId.toRadixString(16).toUpperCase()}';
          _usbPidController.text =
              '0x${first.productId.toRadixString(16).toUpperCase()}';
        }
      } else {
        _isSuccess = false;
        _statusMessage =
            res.errorOrNull?.message ?? 'Failed to list USB devices.';
      }
    });
  }

  Future<void> _runDoctor() async {
    setState(() => _isLoading = true);
    final report = await EscposLink.doctor();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _doctorReport = report;
      _isSuccess = !report.hasErrors;
      _statusMessage =
          'Diagnostics finished: ${report.checks.length} checks performed.';
    });
  }

  int _parseId(String text, int defaultVal) {
    final clean = text.trim();
    if (clean.toLowerCase().startsWith('0x')) {
      return int.tryParse(clean.substring(2), radix: 16) ?? defaultVal;
    }
    return int.tryParse(clean) ?? defaultVal;
  }

  void _setStatus(String msg, {required bool success}) {
    setState(() {
      _statusMessage = msg;
      _isSuccess = success;
    });
  }

  // ---------------------------------------------------------------------------
  // MAIN UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Print Kit Test Code'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildPreviewTab(),
          _buildWiFiPrintTab(),
          _buildBluetoothPrintTab(),
          _buildUsbPrintTab(),
          _buildSunmiPrintTab(),
          _buildTsplLabelTab(),
          _buildVirtualTestTab(),
          _buildDoctorTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
          if (idx == 4) {
            _checkSunmiPaperWidth();
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt), label: 'Preview'),
          NavigationDestination(icon: Icon(Icons.wifi), label: 'WiFi Print'),
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            label: 'Bluetooth',
          ),
          NavigationDestination(icon: Icon(Icons.usb), label: 'USB'),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: 'Sunmi D3',
          ),
          NavigationDestination(
            icon: Icon(Icons.label_outlined),
            selectedIcon: Icon(Icons.label),
            label: 'Label TSPL',
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

  // ---------------------------------------------------------------------------
  // TABS
  // ---------------------------------------------------------------------------

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
                    onSelectionChanged: (set) =>
                        setState(() => _selectedProfile = set.first),
                  ),
                  const SizedBox(height: 12.0),
                  const Text('Receipt Layout Format:'),
                  const SizedBox(height: 8.0),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Standard 2-Column'),
                        icon: Icon(Icons.table_rows),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('5-Column Order Table'),
                        icon: Icon(Icons.table_chart),
                      ),
                    ],
                    selected: {_use5ColumnReceipt},
                    onSelectionChanged: (set) =>
                        setState(() => _use5ColumnReceipt = set.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Center(
            child: Text(
              _use5ColumnReceipt
                  ? 'Live 5-Column Table Preview (${_selectedProfile.dotsWidth} dots)'
                  : 'Live Receipt Preview (Bangla, Chinese, Japanese, Arabic, English)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8.0),
          ReceiptPreview(
            receipt: _getActiveReceipt(),
            profile: _selectedProfile,
          ),
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
            'Connects directly to an ESC/POS receipt printer on your network over TCP port 9100.',
          ),
          const SizedBox(height: 16.0),
          FilledButton.tonalIcon(
            onPressed: _isLoading ? null : _scanNetworkPrinters,
            icon: const Icon(Icons.radar),
            label: const Text('Scan Network Printers'),
          ),
          if (_discoveredNetworkDevices.isNotEmpty) ...[
            const SizedBox(height: 12.0),
            DropdownButtonFormField<NetworkDevice>(
              initialValue:
                  _discoveredNetworkDevices.contains(_selectedNetworkDevice)
                  ? _selectedNetworkDevice
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Discovered Network Printer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.print_outlined),
              ),
              items: _discoveredNetworkDevices.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(
                    d.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (d) {
                if (d != null) {
                  setState(() {
                    _selectedNetworkDevice = d;
                    _hostController.text = d.ip;
                    _portController.text = '${d.port}';
                  });
                }
              },
            ),
          ],
          const SizedBox(height: 12.0),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Printer IP Address',
              hintText: '192.168.0.101',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lan),
            ),
          ),
          const SizedBox(height: 12.0),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Port (default 9100)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _printWiFi(),
            icon: const Icon(Icons.print),
            label: const Text('Print Sample Multi-Language Receipt'),
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _printWiFi(testPageOnly: true),
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
          ),
          const SizedBox(height: 16.0),
          FilledButton.tonalIcon(
            onPressed: _isLoading ? null : _scanBluetooth,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Scan Paired Bluetooth Devices'),
          ),
          const SizedBox(height: 12.0),
          DropdownButtonFormField<BluetoothDevice>(
            initialValue: _pairedBtDevices.contains(_selectedBtDevice)
                ? _selectedBtDevice
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Paired Bluetooth Device',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.bluetooth_connected),
            ),
            items: _pairedBtDevices.map((d) {
              return DropdownMenuItem(
                value: d,
                child: Text(
                  '${d.name.isNotEmpty ? d.name : "Printer"} (${d.address})',
                ),
              );
            }).toList(),
            onChanged: (d) {
              if (d != null) {
                setState(() {
                  _selectedBtDevice = d;
                  _btAddressController.text = d.address;
                });
              }
            },
          ),
          const SizedBox(height: 12.0),
          TextField(
            controller: _btAddressController,
            decoration: const InputDecoration(
              labelText: 'Bluetooth MAC Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 12.0),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Paper Profile (Width):',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8.0),
                  SegmentedButton<PrinterProfile>(
                    segments: const [
                      ButtonSegment(
                        value: PrinterProfile.generic58,
                        label: Text('58 mm (Mobile Standard)'),
                        icon: Icon(Icons.receipt),
                      ),
                      ButtonSegment(
                        value: PrinterProfile.generic80,
                        label: Text('80 mm (Desktop POS)'),
                        icon: Icon(Icons.table_restaurant),
                      ),
                    ],
                    selected: {_selectedProfile},
                    onSelectionChanged: (set) =>
                        setState(() => _selectedProfile = set.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _printBluetooth(),
            icon: const Icon(Icons.print),
            label: const Text('Print Sample Multi-Language Receipt'),
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed: _isLoading
                ? null
                : () => _printBluetooth(testPageOnly: true),
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
            'Connects directly to thermal printers via USB cable or USB OTG adapter.',
          ),
          const SizedBox(height: 16.0),
          FilledButton.tonalIcon(
            onPressed: _isLoading ? null : _scanUsb,
            icon: const Icon(Icons.usb),
            label: const Text('Scan Connected USB Devices'),
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usbVidController,
                  decoration: const InputDecoration(
                    labelText: 'Vendor ID (VID)',
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.memory),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _printUsb(),
            icon: const Icon(Icons.print),
            label: const Text('Print Sample Multi-Language Receipt'),
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _printUsb(testPageOnly: true),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Print Diagnostic Test Page (Ruler & Languages)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSunmiPrintTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sunmi Built-in Thermal Printer',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6.0),
          const Text(
            'Connects directly to the internal thermal receipt printer on Sunmi POS terminals (e.g. Sunmi D3, V2, T2).',
          ),
          const SizedBox(height: 16.0),
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(14.0),
              child: Row(
                children: [
                  Icon(Icons.point_of_sale, size: 36.0, color: Colors.blue),
                  SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sunmi POS Hardware Integration',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.0,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          'Uses Sunmi PrinterX SDK to send ESC/POS commands directly to the built-in printer with auto-cutter and drawer support.',
                          style: TextStyle(fontSize: 12.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Paper Profile (Width):',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8.0),
                  SegmentedButton<PrinterProfile>(
                    segments: const [
                      ButtonSegment(
                        value: PrinterProfile.sunmi80,
                        label: Text('80 mm (Sunmi D3 Standard)'),
                        icon: Icon(Icons.table_restaurant),
                      ),
                      ButtonSegment(
                        value: PrinterProfile.sunmi58,
                        label: Text('58 mm (Sunmi V2 Mobile)'),
                        icon: Icon(Icons.receipt),
                      ),
                    ],
                    selected: {
                      _selectedProfile == PrinterProfile.generic58 ||
                              _selectedProfile == PrinterProfile.sunmi58
                          ? PrinterProfile.sunmi58
                          : PrinterProfile.sunmi80
                    },
                    onSelectionChanged: (set) =>
                        setState(() => _selectedProfile = set.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _printSunmi(),
            icon: const Icon(Icons.print),
            label: const Text('Print Sample Multi-Language Receipt'),
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed:
                _isLoading ? null : () => _printSunmi(testPageOnly: true),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Print Diagnostic Test Page (Ruler & Languages)'),
          ),
          const SizedBox(height: 10.0),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _openSunmiDrawer,
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Kick Cash Drawer (Sunmi API)'),
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
            'Test the complete encoding pipeline (text shaping, 1-bit thermal rasterization, '
            'ESC/POS commands) in memory without needing a physical printer.',
          ),
          const SizedBox(height: 16.0),
          FilledButton.icon(
            onPressed: _isLoading ? null : _runVirtualPrintTest,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run Virtual Print Test'),
          ),
          const SizedBox(height: 16.0),
          _buildStatusBanner(),
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
                onPressed: _isLoading ? null : _runDoctor,
                icon: const Icon(Icons.refresh),
                label: const Text('Check'),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          if (_doctorReport != null)
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
                  subtitle: Text(
                    check.message +
                        (check.hint != null ? '\nHint: ${check.hint}' : ''),
                  ),
                ),
              )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Tap "Check" to test Android permissions and printer support.',
                ),
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
            _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
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

  // ---------------------------------------------------------------------------
  // TSPL LABEL PRINTER TAB & ACTIONS
  // ---------------------------------------------------------------------------

  Widget _buildTsplLabelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.label, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'TSPL Barcode & Sticker Label Printer\nSupports USB, WiFi, and Bluetooth (20x30, 30x20, 40x30, 60x40, etc.)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // 1. Size Selector Dropdown & Rotation Toggle
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. SELECT LABEL SIZE & ORIENTATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TsplSize>(
                          initialValue: _selectedTsplSize,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            labelText: 'Sticker Dimensions',
                          ),
                          items: TsplSize.presets.map((s) {
                            return DropdownMenuItem<TsplSize>(
                              value: s,
                              child: Text(s.name),
                            );
                          }).toList(),
                          onChanged: (newSize) {
                            if (newSize != null) {
                              setState(() => _selectedTsplSize = newSize);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.screen_rotation),
                        tooltip: 'Rotate 90° (Swap Horizontal & Vertical)',
                        onPressed: () {
                          setState(() => _selectedTsplSize = _selectedTsplSize.flipped);
                        },
                      ),
                      const SizedBox(width: 4.0),
                      IconButton.filledTonal(
                        icon: Icon(_selectedTsplDirection == TsplDirection.normal
                            ? Icons.arrow_downward
                            : Icons.arrow_upward),
                        tooltip: _selectedTsplDirection == TsplDirection.normal
                            ? 'Feed Direction: Normal (Tap to invert 180°)'
                            : 'Feed Direction: Inverted 180° (Tap for normal)',
                        onPressed: () {
                          setState(() {
                            _selectedTsplDirection = _selectedTsplDirection == TsplDirection.normal
                                ? TsplDirection.reverse
                                : TsplDirection.normal;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    'Horizontal (Width / X): ${_selectedTsplSize.widthMm.toInt()} mm | Vertical (Height / Y): ${_selectedTsplSize.heightMm.toInt()} mm | Feed: ${_selectedTsplDirection == TsplDirection.normal ? "Normal" : "Inverted 180°"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // 2. Transport Selector (USB, WiFi, Bluetooth)
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. CONNECTION MEDIUM (USB, WiFi, Bluetooth)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8.0),
                  SegmentedButton<Transport>(
                    segments: const [
                      ButtonSegment(value: Transport.usb, icon: Icon(Icons.usb), label: Text('USB')),
                      ButtonSegment(value: Transport.wifi, icon: Icon(Icons.wifi), label: Text('WiFi')),
                      ButtonSegment(value: Transport.bluetooth, icon: Icon(Icons.bluetooth), label: Text('Bluetooth')),
                    ],
                    selected: {_selectedTsplTransport},
                    onSelectionChanged: (set) {
                      setState(() => _selectedTsplTransport = set.first);
                    },
                  ),
                  const SizedBox(height: 12.0),
                  if (_selectedTsplTransport == Transport.usb) ...[
                    FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : _scanUsb,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Attached USB Printers'),
                    ),
                    if (_usbDevices.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      DropdownButtonFormField<UsbDevice>(
                        initialValue: _usbDevices.contains(_selectedUsbDevice) ? _selectedUsbDevice : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Attached USB Device',
                          border: OutlineInputBorder(),
                        ),
                        items: _usbDevices.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(d.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (d) => setState(() => _selectedUsbDevice = d),
                      ),
                    ],
                  ],
                  if (_selectedTsplTransport == Transport.wifi) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _hostController,
                            decoration: const InputDecoration(
                              labelText: 'Printer IP',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_selectedTsplTransport == Transport.bluetooth) ...[
                    FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : _scanBluetooth,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Scan Paired Bluetooth Printers'),
                    ),
                    if (_pairedBtDevices.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      DropdownButtonFormField<BluetoothDevice>(
                        initialValue: _pairedBtDevices.contains(_selectedBtDevice) ? _selectedBtDevice : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Paired Device',
                          border: OutlineInputBorder(),
                        ),
                        items: _pairedBtDevices.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text('${d.name} (${d.address})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (d) => setState(() => _selectedBtDevice = d),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // 3. Label Template Selector
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('3. LABEL CONTENT TEMPLATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      ChoiceChip(
                        label: const Text('Retail Price Tag'),
                        selected: _selectedTsplTemplate == 0,
                        onSelected: (val) => setState(() => _selectedTsplTemplate = 0),
                      ),
                      ChoiceChip(
                        label: const Text('Product Barcode'),
                        selected: _selectedTsplTemplate == 1,
                        onSelected: (val) => setState(() => _selectedTsplTemplate = 1),
                      ),
                      ChoiceChip(
                        label: const Text('Multilingual (বাং/عربي)'),
                        selected: _selectedTsplTemplate == 2,
                        onSelected: (val) => setState(() => _selectedTsplTemplate = 2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // 4. Live Label Preview
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('4. LIVE STICKER PREVIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12.0),
                  TsplLabelPreview(
                    label: _buildActiveTsplLabel(),
                    maxWidth: 320.0,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // 5. Actions
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.print),
                      label: Text('Print Sticker Label (${_selectedTsplSize.widthMm.toInt()}×${_selectedTsplSize.heightMm.toInt()} mm)'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14.0)),
                      onPressed: _executeTsplPrint,
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.arrow_downward),
                            label: const Text('Feed / Tear'),
                            onPressed: _executeTsplFeed,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.tune),
                            label: const Text('Calibrate Gap'),
                            onPressed: _executeTsplCalibrate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12.0),
            _buildStatusBanner(),
          ],
        ],
      ),
    );
  }

  TsplLabel _buildActiveTsplLabel() {
    final size = _selectedTsplSize;
    final wMm = size.widthMm;
    final hMm = size.heightMm;

    // Direct, beginner-friendly TSPL construction using physical millimeters!
    // Horizontal (X) = distance from left edge in mm.
    // Vertical (Y)   = distance from top edge in mm.
    final label = TsplLabel(size: size)..setDirection(_selectedTsplDirection);

    switch (_selectedTsplTemplate) {
      case 0: // Retail Price Tag (Optimized for 40x30, 50x30, 60x40)
        // 1. Clean outer margin border
        label.boxMm(
          horizontal: 1.0,
          vertical: 1.0,
          endHorizontal: wMm - 1.0,
          endVertical: hMm - 1.0,
          thickness: 2,
        );

        // 2. Store Header Title
        label.textMm(
          'ORGANIC STORE',
          horizontal: 2.0,
          vertical: 2.0,
          font: wMm < 35.0 ? TsplFont.font2 : TsplFont.font3,
        );

        // 3. Crisp horizontal divider line (spaced below header)
        label.lineMm(
          horizontal: 2.0,
          vertical: 6.0,
          width: wMm - 4.0,
          thickness: 1,
        );

        // 4. English Product Name
        label.textMm(
          'Sourdough Bread',
          horizontal: 2.0,
          vertical: 7.5,
          font: TsplFont.font2,
        );

        // 5. Native Multilingual Text (Bangla: টাটকা রুটি) - crisp anti-aliased bitmap
        label.textRasterMm(
          'টাটকা রুটি',
          horizontal: 2.0,
          vertical: 11.0,
          fontSize: 13.0,
          languageTag: 'bn',
        );

        // 6. Barcode & QR Code elements (Clean side-by-side or stacked without overlap)
        if (wMm >= 48.0) {
          // Wide label (50x30, 60x40): Barcode on left, QR code on right
          label.barcodeMm(
            '20491024',
            horizontal: 2.0,
            vertical: 15.0,
            height: (hMm * 0.25).clamp(5.0, 10.0),
            narrow: 2,
            wide: 2,
          );
          label.qrMm(
            'https://posprint.link',
            horizontal: wMm - 13.0,
            vertical: 14.5,
            size: (wMm ~/ 16).clamp(2, 4),
          );
          label.textMm(
            'PRICE: \$4.50',
            horizontal: 2.0,
            vertical: hMm - 5.5,
            font: TsplFont.font4,
          );
        } else {
          // Compact label (40x30, 30x40):
          label.barcodeMm(
            '20491024',
            horizontal: 2.0,
            vertical: 15.0,
            height: 5.5,
            narrow: 1,
            wide: 2,
          );
          label.qrMm(
            'https://posprint.link',
            horizontal: wMm - 11.5,
            vertical: 15.0,
            size: 2,
          );
          label.textMm(
            'PRICE: \$4.50',
            horizontal: 2.0,
            vertical: hMm - 5.0,
            font: TsplFont.font3,
          );
        }
        break;

      case 1: // Product Barcode Tag
        label.boxMm(
          horizontal: 1.0,
          vertical: 1.0,
          endHorizontal: wMm - 1.0,
          endVertical: hMm - 1.0,
          thickness: 2,
        );
        label.textMm(
          'SKU: ACME-8892',
          horizontal: 2.5,
          vertical: 2.5,
          font: wMm < 35.0 ? TsplFont.font2 : TsplFont.font3,
        );
        label.lineMm(
          horizontal: 2.5,
          vertical: 6.5,
          width: wMm - 5.0,
          thickness: 1,
        );

        final barHeight = (hMm * 0.35).clamp(6.0, 16.0);
        label.barcodeMm(
          '8892019482',
          horizontal: 2.5,
          vertical: 8.5,
          height: barHeight,
          narrow: 2,
          wide: 2,
        );

        if (wMm >= 45.0) {
          label.qrMm(
            'https://acme.link/8892',
            horizontal: wMm - 13.0,
            vertical: 8.5,
            size: (wMm ~/ 16).clamp(2, 4),
          );
        }
        label.textMm(
          'LOT: 2026-11 | BIN: A-12',
          horizontal: 2.5,
          vertical: hMm - 5.0,
          font: TsplFont.font2,
        );
        break;

      case 2: // Multilingual Badge (Bangla & Arabic)
        label.boxMm(
          horizontal: 1.0,
          vertical: 1.0,
          endHorizontal: wMm - 1.0,
          endVertical: hMm - 1.0,
          thickness: 2,
        );
        label.textMm(
          'NATURAL HONEY',
          horizontal: 2.5,
          vertical: 2.5,
          font: wMm < 35.0 ? TsplFont.font2 : TsplFont.font3,
        );
        label.lineMm(
          horizontal: 2.5,
          vertical: 6.2,
          width: wMm - 5.0,
          thickness: 1,
        );
        label.textRasterMm(
          'খাঁটি মধু ৫০০ গ্রাম',
          horizontal: 2.5,
          vertical: 7.5,
          fontSize: 13.5,
          languageTag: 'bn',
        );
        label.textRasterMm(
          'عسل نحل طبيعي',
          horizontal: 2.5,
          vertical: 12.0,
          fontSize: 13.5,
          languageTag: 'ar',
        );

        if (hMm >= 35.0) {
          label.barcodeMm(
            '99281726',
            horizontal: 2.5,
            vertical: 17.5,
            height: 7.0,
            narrow: 2,
            wide: 2,
          );
          if (wMm >= 45.0) {
            label.qrMm(
              'https://posprint.link/honey',
              horizontal: wMm - 13.0,
              vertical: 17.5,
              size: 3,
            );
          }
          label.textMm(
            'NET: 500g | \$12.99',
            horizontal: 2.5,
            vertical: hMm - 5.5,
            font: TsplFont.font3,
          );
        } else {
          label.barcodeMm(
            '99281726',
            horizontal: 2.5,
            vertical: 17.0,
            height: 4.5,
            narrow: 1,
            wide: 2,
          );
          label.textMm(
            'NET: 500g | \$12.99',
            horizontal: 2.5,
            vertical: hMm - 4.5,
            font: TsplFont.font2,
          );
        }
        break;
    }

    return label;
  }

  TsplPrinter _createActiveTsplPrinter() {
    switch (_selectedTsplTransport) {
      case Transport.wifi:
        final host = _hostController.text.trim().isEmpty ? '192.168.1.50' : _hostController.text.trim();
        final port = int.tryParse(_portController.text.trim()) ?? 9100;
        return TsplPrinter.wifi(host, port: port, rasterizer: FlutterTextRasterizer());
      case Transport.bluetooth:
        final address = _selectedBtDevice?.address ??
            (_btAddressController.text.trim().isEmpty ? '00:11:22:33:44:55' : _btAddressController.text.trim());
        return TsplPrinter.bluetooth(address, rasterizer: FlutterTextRasterizer());
      case Transport.usb:
      default:
        final vid = _selectedUsbDevice?.vendorId ?? _parseId(_usbVidController.text, 0x0483);
        final pid = _selectedUsbDevice?.productId ?? _parseId(_usbPidController.text, 0x5740);
        return TsplPrinter.usb(vendorId: vid, productId: pid, rasterizer: FlutterTextRasterizer());
    }
  }

  Future<void> _executeTsplPrint() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to TSPL label printer...';
    });
    try {
      final printer = _createActiveTsplPrinter();
      final label = _buildActiveTsplLabel();
      final result = await printer.print(label);
      await printer.close();
      if (mounted) {
        if (result.isOk) {
          _setStatus('Sticker label (${_selectedTsplSize.name}) printed successfully!', success: true);
        } else {
          _setStatus('Label print failed: ${result.errorOrNull?.message}', success: false);
        }
      }
    } catch (e) {
      if (mounted) _setStatus('Error: $e', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeTsplFeed() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Advancing label to tear boundary...';
    });
    try {
      final printer = _createActiveTsplPrinter();
      final res = await printer.formFeed();
      await printer.close();
      if (mounted) {
        _setStatus(res.isOk ? 'Label advanced successfully (FORMFEED)!' : 'Feed failed: ${res.errorOrNull?.message}', success: res.isOk);
      }
    } catch (e) {
      if (mounted) _setStatus('Error: $e', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeTsplCalibrate() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Calibrating label gap sensor (GAPDETECT)...';
    });
    try {
      final printer = _createActiveTsplPrinter();
      final res = await printer.calibrate();
      await printer.close();
      if (mounted) {
        _setStatus(res.isOk ? 'Label gap sensor calibrated successfully!' : 'Calibration failed: ${res.errorOrNull?.message}', success: res.isOk);
      }
    } catch (e) {
      if (mounted) _setStatus('Error: $e', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
