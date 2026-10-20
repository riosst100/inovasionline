import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_exception.dart';
import '../../core/permissions.dart';
import '../../models/parcel.dart';
import '../../providers/providers.dart';
import 'confirm_screen.dart';

/// Scans parcel QR codes one after another. After each confirmation the camera is ready for the
/// next parcel, since a driver loads or hands over several in a row.
///
/// With [expected] set (tapped from the list), only that parcel is accepted.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.expected});

  final Parcel? expected;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _busy = false;
  int _confirmed = 0;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (_busy || code == null) return;
    _busy = true;
    setState(() => _message = 'Memeriksa pesanan...');

    // Location is checked on every scan, not only when the scanner opens.
    if (!await ensureLocationReady(context)) {
      if (mounted) _fail('Scan butuh izin lokasi dan GPS aktif.');
      return;
    }
    if (!mounted) return;

    try {
      final parcel = await ref.read(deliveryServiceProvider).scan(code);
      if (!mounted) return;

      final expected = widget.expected;
      if (expected != null && expected.id != parcel.id) {
        _fail('QR ini milik ${parcel.orderNumber}, bukan ${expected.orderNumber}.');
        return;
      }
      if (parcel.action == ParcelAction.none) {
        _fail('${parcel.orderNumber} tidak bisa diproses (${_statusLabel(parcel.status)}).');
        return;
      }

      setState(() => _message = null);
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ConfirmScreen(parcel: parcel, code: code),
        ),
      );
      if (!mounted) return;

      if (ok == true) {
        if (widget.expected != null) {
          Navigator.of(context).pop();
          return;
        }
        setState(() => _confirmed++);
      }
      _busy = false;
    } catch (e) {
      if (mounted) _fail(errorMessage(e));
    }
  }

  /// Shows [text] for a moment, then accepts scans again.
  void _fail(String text) {
    setState(() => _message = text);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _message = null);
      _busy = false;
    });
  }

  static String _statusLabel(String status) => switch (status) {
    'completed' => 'sudah selesai',
    'on_delivery' => 'sedang diantar kurir lain',
    'cancelled' => 'dibatalkan',
    'processing' => 'belum siap diantar',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    final expected = widget.expected;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(expected == null ? 'Scan QR paket' : 'Scan ${expected.orderNumber}'),
        actions: [IconButton(icon: const Icon(Icons.flash_on), onPressed: _controller.toggleTorch)],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_message != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  else
                    Text(
                      _confirmed == 0
                          ? 'Arahkan kamera ke QR pada paket'
                          : '$_confirmed paket dikonfirmasi. Scan paket berikutnya.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  if (_confirmed > 0) ...[
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Selesai')),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
