import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../models/nearest_address.dart';
import '../../models/region.dart';
import '../../models/user_address.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/delivery_address_provider.dart';
import '../../providers/user_address_provider.dart';
import '../../widgets/address_picker.dart';

const _teal = Color(0xFF0D9488);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

String _errorMessage(Object error, String fallback) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return fallback;
}

/// Opens the form to add an address, or to edit [existing]. It is saved to
/// the account before the sheet closes; returns the saved address, or null
/// when dismissed.
Future<UserAddress?> showUserAddressForm(
  BuildContext context, {
  UserAddress? existing,
}) {
  return showModalBottomSheet<UserAddress>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _UserAddressFormSheet(existing: existing),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.builder});

  final String title;
  final Widget Function(ScrollController controller) builder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(child: builder(scrollController)),
          ],
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  const _BottomButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : (icon != null ? Icon(icon, size: 20) : const SizedBox()),
            label: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SAVED ADDRESS LIST
// ==========================================

/// The user's saved addresses to pick from, with edit, delete and "add new".
/// Pops with the picked (or newly added) address.
class UserAddressListSheet extends ConsumerWidget {
  const UserAddressListSheet({super.key, this.selectedId});

  final String? selectedId;

  Future<void> _add(BuildContext context) async {
    final added = await showUserAddressForm(context);
    if (added != null && context.mounted) Navigator.of(context).pop(added);
  }

  Future<void> _edit(BuildContext context, UserAddress address) =>
      showUserAddressForm(context, existing: address);

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    UserAddress address,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus alamat?'),
        content: Text(
          '${address.label ?? address.recipientName}\n${address.detail}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(userAddressServiceProvider).delete(address.id);
      ref.invalidate(userAddressesProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e, 'Gagal menghapus alamat.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(userAddressesProvider);

    return _SheetFrame(
      title: 'Pilih Alamat Pengiriman',
      builder: (scrollController) => Column(
        children: [
          Expanded(
            child: addresses.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage(e, 'Gagal memuat alamat.'),
                      style: const TextStyle(color: _muted),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(userAddressesProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada alamat tersimpan.',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final address = list[i];
                        return _AddressTile(
                          address: address,
                          selected: address.id == selectedId,
                          onTap: () => Navigator.of(context).pop(address),
                          onEdit: () => _edit(context, address),
                          onDelete: () => _delete(context, ref, address),
                        );
                      },
                    ),
            ),
          ),
          _BottomButton(
            label: 'Tambah Alamat Baru',
            icon: Icons.add_location_alt_outlined,
            onPressed: () => _add(context),
          ),
        ],
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final UserAddress address;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = address.label;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? _teal : _border,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          color: selected ? const Color(0xFFF0FDF4) : Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? _teal : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null) ...[
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _teal,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    '${address.recipientName} · ${address.recipientPhone}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.detail,
                    style: const TextStyle(fontSize: 13, color: _ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.regionLine,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: _muted),
              onSelected: (action) =>
                  action == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Ubah')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ADD / EDIT ADDRESS FORM
// ==========================================

class _UserAddressFormSheet extends ConsumerStatefulWidget {
  const _UserAddressFormSheet({this.existing});

  final UserAddress? existing;

  @override
  ConsumerState<_UserAddressFormSheet> createState() =>
      _UserAddressFormSheetState();
}

class _UserAddressFormSheetState extends ConsumerState<_UserAddressFormSheet> {
  // An older address may carry a label that is no longer offered; the user
  // then has to pick one of the current ones.
  late String? _label = widget.existing == null
      ? userAddressLabels.first
      : (userAddressLabels.contains(widget.existing!.label)
            ? widget.existing!.label
            : null);
  late final _nameController = TextEditingController();
  late final _phoneController = TextEditingController();
  late final _detailController = TextEditingController(
    text: widget.existing?.detail,
  );
  late AddressSelection _region =
      widget.existing?.region ?? const AddressSelection();
  bool _saving = false;
  String? _error;

  /// A new address starts from the location last detected by GPS; the user
  /// can still change every field. The picker is held back until it is
  /// resolved because it only reads its initial value once.
  late bool _prefilling = widget.existing == null;

  /// Set once the user tried to save; from then on empty required fields
  /// are marked.
  bool _submitted = false;

  String? _required(TextEditingController c, String message) =>
      _submitted && c.text.trim().isEmpty ? message : null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) _prefillFromGps();
    // A new address starts with the account's own name and phone.
    final user = ref.read(authProvider).user;
    _nameController.text = existing?.recipientName ?? user?.name ?? '';
    _phoneController.text = existing?.recipientPhone ?? user?.phone ?? '';
  }

  Future<void> _prefillFromGps() async {
    final gps = ref.read(deliveryAddressProvider);
    AddressSelection? region;
    if (gps != null) {
      try {
        region = await _resolveRegion(gps);
      } catch (_) {
        // Fall back to an empty picker.
      }
    }
    if (!mounted) return;
    setState(() {
      if (region != null) _region = region;
      _prefilling = false;
    });
  }

  Future<AddressSelection> _resolveRegion(NearestAddress gps) async {
    final service = ref.read(regionServiceProvider);
    Region? find(List<Region> list, String code) =>
        list.where((r) => r.code == code).firstOrNull;

    final province = find(await service.provinces(), gps.provinceCode);
    final city = find(await service.cities(gps.provinceCode), gps.cityCode);
    final district = find(await service.districts(gps.cityCode), gps.districtCode);
    final village = find(await service.villages(gps.districtCode), gps.villageCode);
    return AddressSelection(
      province: province,
      city: city,
      district: district,
      village: village,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  bool get _valid =>
      _label != null &&
      _region.isComplete &&
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _detailController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    if (!_valid) {
      setState(() => _submitted = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final input = UserAddressInput(
      label: _label!,
      recipientName: _nameController.text.trim(),
      recipientPhone: _phoneController.text.trim(),
      region: _region,
      detail: _detailController.text.trim(),
    );

    try {
      final service = ref.read(userAddressServiceProvider);
      final existing = widget.existing;
      final saved = existing == null
          ? await service.create(input)
          : await service.update(existing.id, input);
      ref.invalidate(userAddressesProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorMessage(e, 'Gagal menyimpan alamat.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.existing == null ? 'Tambah Alamat' : 'Ubah Alamat',
      builder: (scrollController) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                const Text(
                  'Label Alamat',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in userAddressLabels)
                      ChoiceChip(
                        label: Text(label),
                        selected: _label == label,
                        onSelected: (_) => setState(() => _label = label),
                        selectedColor: const Color(0xFFCCFBF1),
                        side: BorderSide(
                          color: _label == label ? _teal : _border,
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _label == label ? _teal : _ink,
                        ),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    label: requiredLabel('Nama Penerima'),
                    errorText: _required(_nameController, 'Nama penerima wajib diisi'),
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    label: requiredLabel('Nomor Telepon Penerima'),
                    errorText: _required(_phoneController, 'Nomor telepon wajib diisi'),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                if (_prefilling)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  AddressPicker(
                    autoSelectSingle: true,
                    initial: _region,
                    showErrors: _submitted,
                    onChanged: (selection) =>
                        setState(() => _region = selection),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _detailController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    label: requiredLabel(
                      'Detail Alamat (Nama Jalan, No. Rumah, RT/RW, Patokan)',
                    ),
                    errorText: _required(_detailController, 'Detail alamat wajib diisi'),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '*',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                      TextSpan(text: ' ini wajib diisi'),
                    ],
                  ),
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          _BottomButton(
            label: 'Simpan Alamat',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
