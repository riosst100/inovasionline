import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_address_provider.dart';
import '../../widgets/address_picker.dart';

/// Lets the user pick one of the served cities, plus district and village,
/// by hand: from the out-of-area screen, or "Pilih alamat manual" in the
/// home header's address dropdown. The picker only offers the areas configured
/// under Cakupan Kota.
///
/// Needs a [Navigator] to sit in (dropdown menus open into it); the
/// permission gate, which is above the app's router, hosts it in its own.
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
        if (!didPop && !_saving) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black54,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Material(
                      color: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 18, 8, 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.14),
                                  AppColors.primary.withValues(alpha: 0.02),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_location_alt_rounded,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Pilih Alamat Pengiriman',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: _saving ? null : widget.onBack,
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Pilih salah satu wilayah yang sudah '
                                    'terjangkau layanan Inovasi Online.',
                                    style: TextStyle(
                                      color: AppColors.mutedForeground,
                                      fontSize: 13.5,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_error != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _error!,
                                        style: TextStyle(color: Colors.red.shade700),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  AddressPicker(
                                    autoSelectSingle: true,
                                    onChanged: (address) =>
                                        setState(() => _address = address),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed:
                                    _saving || !_address.isComplete ? null : _save,
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Route for [ManualAddressScreen]: see-through, so it reads as a popup over
/// whatever is underneath.
Route<void> manualAddressRoute({
  required VoidCallback onBack,
  required VoidCallback onSaved,
}) {
  return PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (_, _, _) =>
        ManualAddressScreen(onBack: onBack, onSaved: onSaved),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
