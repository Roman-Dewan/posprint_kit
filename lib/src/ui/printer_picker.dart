import 'package:flutter/material.dart';

import '../core/printer_profile.dart';
import '../printer.dart';

/// A drop-in modal or screen widget allowing users and developers to configure,
/// discover, and select a thermal printer.
class PrinterPicker extends StatefulWidget {
  const PrinterPicker({
    super.key,
    required this.onPrinterSelected,
    this.initialProfile = PrinterProfile.generic80,
  });

  /// Callback invoked when a printer is tested and chosen.
  final void Function(EscposPrinter printer) onPrinterSelected;

  /// Default printer hardware profile.
  final PrinterProfile initialProfile;

  @override
  State<PrinterPicker> createState() => _PrinterPickerState();
}

class _PrinterPickerState extends State<PrinterPicker> {
  Transport _selectedTransport = Transport.wifi;
  late PrinterProfile _profile;

  // Network controllers
  final _hostController = TextEditingController(text: '192.168.1.50');
  final _portController = TextEditingController(text: '9100');

  // Bluetooth controllers
  final _btAddressController = TextEditingController(text: '00:11:22:33:44:55');

  // USB controllers
  final _usbVidController = TextEditingController(text: '0x04B8');
  final _usbPidController = TextEditingController(text: '0x0202');

  bool _isTesting = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
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

  EscposPrinter _buildCurrentPrinter() {
    switch (_selectedTransport) {
      case Transport.wifi:
        final port = int.tryParse(_portController.text.trim()) ?? 9100;
        return EscposPrinter.wifi(
          _hostController.text.trim(),
          port: port,
          profile: _profile,
        );
      case Transport.bluetooth:
        return EscposPrinter.bluetooth(
          _btAddressController.text.trim(),
          profile: _profile,
        );
      // OLD:
      // case Transport.usb:
      //   return EscposPrinter.usb(
      //     vendorId: 0x04b8,
      //     productId: 0x0202,
      //     profile: _profile,
      //   );
      case Transport.usb:
        final rawVid = _usbVidController.text.trim();
        final rawPid = _usbPidController.text.trim();
        final vid = rawVid.toLowerCase().startsWith('0x')
            ? int.tryParse(rawVid.substring(2), radix: 16) ?? 0x04b8
            : int.tryParse(rawVid) ?? 0x04b8;
        final pid = rawPid.toLowerCase().startsWith('0x')
            ? int.tryParse(rawPid.substring(2), radix: 16) ?? 0x0202
            : int.tryParse(rawPid) ?? 0x0202;
        return EscposPrinter.usb(
          vendorId: vid,
          productId: pid,
          profile: _profile,
        );
      case Transport.ble:
        return EscposPrinter.bluetooth(
          _btAddressController.text.trim(),
          profile: _profile,
        );
    }
  }

  Future<void> _testPrinter() async {
    setState(() {
      _isTesting = true;
      _statusMessage = 'Connecting and sending test receipt...';
      _isSuccess = false;
    });

    final printer = _buildCurrentPrinter();
    try {
      final res = await printer.printTestPage();
      await printer.close();

      setState(() {
        _isTesting = false;
        if (res.isOk) {
          _isSuccess = true;
          _statusMessage = 'Test page sent successfully!';
        } else {
          _isSuccess = false;
          _statusMessage = '${res.errorOrNull?.message}\n${res.errorOrNull?.hint}';
        }
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _isSuccess = false;
        _statusMessage = 'Connection error: $e';
      });
    }
  }

  void _confirmSelection() {
    widget.onPrinterSelected(_buildCurrentPrinter());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.print, size: 28.0),
                const SizedBox(width: 12.0),
                Text(
                  'Select Thermal Printer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Connection type selector
            SegmentedButton<Transport>(
              segments: const [
                ButtonSegment(
                  value: Transport.wifi,
                  label: Text('WiFi / LAN'),
                  icon: Icon(Icons.wifi),
                ),
                ButtonSegment(
                  value: Transport.bluetooth,
                  label: Text('Bluetooth'),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment(
                  value: Transport.usb,
                  label: Text('USB OTG'),
                  icon: Icon(Icons.usb),
                ),
              ],
              selected: {_selectedTransport},
              onSelectionChanged: (set) {
                setState(() {
                  _selectedTransport = set.first;
                  _statusMessage = null;
                });
              },
            ),
            const SizedBox(height: 16.0),

            // Configuration inputs per transport
            if (_selectedTransport == Transport.wifi) ...[
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
                  labelText: 'TCP Port',
                  hintText: '9100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
            ] else if (_selectedTransport == Transport.bluetooth) ...[
              TextField(
                controller: _btAddressController,
                decoration: const InputDecoration(
                  labelText: 'Bluetooth MAC Address / Name',
                  hintText: '00:11:22:33:44:55',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bluetooth_searching),
                ),
              ),
            ] else ...[
              // OLD:
              // const ListTile(
              //   leading: Icon(Icons.usb),
              //   title: Text('USB Thermal Printer'),
              //   subtitle: Text('Plug printer into Android device using an OTG cable.'),
              // ),
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
            ],
            const SizedBox(height: 16.0),

            // Paper profile selector
            DropdownButtonFormField<PrinterProfile>(
              initialValue: _profile,
              decoration: const InputDecoration(
                labelText: 'Paper Size Profile',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PrinterProfile.generic80,
                  child: Text('80 mm Paper (576 dots / 48 columns)'),
                ),
                DropdownMenuItem(
                  value: PrinterProfile.generic58,
                  child: Text('58 mm Paper (384 dots / 32 columns)'),
                ),
              ],
              onChanged: (p) {
                if (p != null) setState(() => _profile = p);
              },
            ),
            const SizedBox(height: 16.0),

            // Status message
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: _isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                    fontSize: 13.0,
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
            ],

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testPrinter,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16.0,
                            height: 16.0,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          )
                        : const Icon(Icons.receipt_long),
                    label: const Text('Print Test Page'),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _confirmSelection,
                    icon: const Icon(Icons.check),
                    label: const Text('Save & Select'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

