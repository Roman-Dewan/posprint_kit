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
  List<NetworkDevice> _discoveredNetworkDevices = [];
  NetworkDevice? _selectedNetworkDevice;
  DoctorReport? _doctorReport;

  // Status & loading indicators
  String? _statusMessage;
  bool _isSuccess = true;
  bool _isLoading = false;

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
          _buildVirtualTestTab(),
          _buildDoctorTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt), label: 'Preview'),
          NavigationDestination(icon: Icon(Icons.wifi), label: 'WiFi Print'),
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            label: 'Bluetooth',
          ),
          NavigationDestination(icon: Icon(Icons.usb), label: 'USB'),
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
}
