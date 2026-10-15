import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_address_provider.dart';
import '../../widgets/address_picker.dart';

/// Lets a user whose GPS is outside the service area pick one of the served
/// cities, plus district and village, by hand. The picker only offers the
/// areas configured under Cakupan Kota.
///
/// Meant to be hosted in its own [Navigator] (the permission gate sits above
/// the app's router, and dropdown menus need a Navigator to open into).
class ManualAddressScreen extends ConsumerStatefulWidget {
  const ManualAddressScreen({
    super.key,
    required this.onBack,
    required this.onSaved,
  });

  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  ConsumerState<ManualAddressScreen> createState() =>
      _ManualAddressScreenState();
}

class _ManualAddressScreenState extends ConsumerState<ManualAddressScreen> {
  AddressSelection _address = const AddressSelection();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_address.isComplete) {
      setState(() => _error = 'Pilih kota, kecamatan, dan desa dulu.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final signedIn =
        ref.read(authProvider).status == AuthStatus.authenticated;

    final bool saved;
    if (signedIn) {
      saved = await ref.read(authProvider.notifier).updateAddress(
            provinceCode: _address.province!.code,
            cityCode: _address.city!.code,
            districtCode: _address.district!.code,
            villageCode: _address.village!.code,
          );
    } else {
      await ref.read(guestAddressProvider.notifier).setManual(_address);
      saved = true;
    }

    if (!mounted) return;

    if (saved) {
      ref.read(locationFailureProvider.notifier).state = null;
      widget.onSaved();
      return;
    }

    setState(() {
      _saving = false;
      _error = ref.read(authProvider).error ?? 'Gagal menyimpan alamat.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Pilih Alamat Pengiriman'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving ? null : widget.onBack,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pilih salah satu wilayah yang sudah terjangkau layanan '
                  'Inovasi Online.',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                AddressPicker(
                  onChanged: (address) => setState(() => _address = address),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving || !_address.isComplete ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Alamat'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
