import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/permissions.dart';
import '../../models/parcel.dart';
import '../../providers/providers.dart';

/// Shows the scanned parcel and confirms the next step with a camera photo as proof:
/// pickup ("dikirim") or handover ("diterima"). Pops `true` once confirmed.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key, required this.parcel, this.code});

  final Parcel parcel;
  /// Scanned QR, if any; picking the parcel from the list needs none.
  final String? code;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  final _picker = ImagePicker();
  XFile? _photo;
  bool _submitting = false;

  bool get _isShip => widget.parcel.action == ParcelAction.ship;

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null) return;
    // Pickup and handover both need GPS on.
    if (!await ensureLocationReady(context) || !mounted) return;
    setState(() => _submitting = true);

    final service = ref.read(deliveryServiceProvider);
    final tracker = ref.read(deliveryTrackerProvider);
    var allDelivered = false;
    try {
      if (_isShip) {
        await service.ship(widget.parcel, code: widget.code, photoPath: photo.path);
        // Sharing location starts right at pickup, so the buyer can follow the parcel straight away.
        await tracker.start();
      } else {
        await service.deliver(widget.parcel, code: widget.code, photoPath: photo.path);
        // Last parcel handed over: stop using GPS. Others still on the way keep it running.
        // A failed refresh is not a failed handover; the list refresh on return retries the check.
        final remaining = await ref.refresh(parcelsProvider(false).future).catchError((_) => [widget.parcel]);
        allDelivered = remaining.isEmpty;
        if (allDelivered) await tracker.stop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_isShip ? 'Ditandai sedang diantar.' : 'Ditandai selesai diterima.')));
      if (allDelivered) await offerGpsOff(context);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final photo = _photo;

    return Scaffold(
      appBar: AppBar(title: Text(_isShip ? 'Konfirmasi dikirim' : 'Konfirmasi diterima')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(parcel.orderNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _Row('Penerima', parcel.receiver),
                  if (parcel.customerPhone != null) _Row('Telepon', parcel.customerPhone!),
                  if (parcel.address != null) _Row('Alamat', parcel.address!),
                  _Row('Barang', '${parcel.itemsCount} item'),
                  _Row('Paket', '${parcel.packagesCount} paket'),
                  if (parcel.customerNotes?.isNotEmpty ?? false) _Row('Catatan', parcel.customerNotes!),
                ],
              ),
            ),
          ),
          if (parcel.packagesCount > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isShip
                          ? 'Pesanan ini terdiri dari ${parcel.packagesCount} paket. Pastikan semua paket dibawa.'
                          : 'Serahkan semua ${parcel.packagesCount} paket ke penerima.',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (parcel.codAmount > 0 && !_isShip) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Terima uang tunai ${formatCurrency(parcel.codAmount)} dari pembeli.',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _isShip ? 'Foto paket saat diambil' : 'Foto bukti paket diterima',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _submitting ? null : _takePhoto,
            child: Container(
              height: 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: photo == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 40, color: AppColors.mutedForeground),
                        SizedBox(height: 8),
                        Text('Ketuk untuk ambil foto', style: TextStyle(color: AppColors.mutedForeground)),
                      ],
                    )
                  : Image.file(File(photo.path), fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          if (photo != null)
            TextButton.icon(
              onPressed: _submitting ? null : _takePhoto,
              icon: const Icon(Icons.refresh),
              label: const Text('Foto ulang'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: photo == null || _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isShip ? 'Konfirmasi dikirim' : 'Konfirmasi diterima'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: const TextStyle(color: AppColors.mutedForeground)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
