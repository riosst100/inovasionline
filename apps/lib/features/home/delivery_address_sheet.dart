import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/nearest_address.dart';
import '../../providers/delivery_address_provider.dart';
import '../shell/manual_address_screen.dart';

/// Opens the by-hand address picker over the whole app (above the bottom
/// navigation) and closes it again once saved or backed out of.
Future<void> _pushManualAddress(NavigatorState navigator) {
  return navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => ManualAddressScreen(
        onBack: navigator.pop,
        onSaved: navigator.pop,
      ),
    ),
  );
}

/// Delivery address chooser behind the header's dropdown: the saved
/// addresses, the device's current location, or a new one picked by hand.
Future<void> showDeliveryAddressSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _DeliveryAddressSheet(),
    );

class _DeliveryAddressSheet extends ConsumerStatefulWidget {
  const _DeliveryAddressSheet();

  @override
  ConsumerState<_DeliveryAddressSheet> createState() =>
      _DeliveryAddressSheetState();
}

class _DeliveryAddressSheetState extends ConsumerState<_DeliveryAddressSheet> {
  bool _locating = false;
  String? _error;

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final error =
        await ref.read(deliveryAddressActionsProvider).useMyLocation();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _locating = false;
        _error = error;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Alamat pengiriman diatur sesuai lokasi kamu.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _pickManually() {
    final navigator = Navigator.of(context);
    navigator.pop();
    _pushManualAddress(navigator);
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(savedDeliveryAddressesProvider);
    final current = ref.watch(deliveryAddressProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilih Alamat Pengiriman',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Belum ada alamat tersimpan.',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              )
            else
              for (final address in addresses) ...[
                _SavedAddressTile(
                  address: address,
                  selected: address.villageCode == current?.villageCode,
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 4),
            _ActionTile(
              icon: Icons.my_location_rounded,
              title: 'Gunakan lokasi saya saat ini',
              subtitle: 'Nyalakan GPS dan tentukan ulang lokasi kamu',
              busy: _locating,
              onTap: _locating ? null : _useMyLocation,
            ),
            _ActionTile(
              icon: Icons.edit_location_alt_rounded,
              title: 'Pilih alamat manual',
              subtitle: 'Pilih kota, kecamatan, dan desa sendiri',
              onTap: _locating ? null : _pickManually,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
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
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  const _SavedAddressTile({required this.address, required this.selected});

  final NearestAddress address;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.06)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.primary : AppColors.mutedForeground,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alamat Utama',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address.label.isEmpty ? '-' : address.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedForeground,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        busy ? 'Menentukan lokasi kamu...' : title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
