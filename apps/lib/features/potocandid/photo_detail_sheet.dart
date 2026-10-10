import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/potocandid_photo.dart';
import 'potocandid_providers.dart';

Future<void> showPhotoDetailSheet(BuildContext context, PotoCandidPhoto photo) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => PhotoDetailSheet(photo: photo),
  );
}

class PhotoDetailSheet extends ConsumerStatefulWidget {
  const PhotoDetailSheet({super.key, required this.photo});

  final PotoCandidPhoto photo;

  @override
  ConsumerState<PhotoDetailSheet> createState() => _PhotoDetailSheetState();
}

class _PhotoDetailSheetState extends ConsumerState<PhotoDetailSheet> {
  bool _purchasing = false;

  Future<void> _purchase() async {
    setState(() => _purchasing = true);
    final success = await ref.read(potoCandidProvider.notifier).purchasePhoto(widget.photo.id);
    if (!mounted) return;
    setState(() => _purchasing = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto berhasil dibeli'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final error = ref.watch(potoCandidProvider).error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: photo.displayUrl != null
                    ? CachedNetworkImage(imageUrl: photo.displayUrl!, fit: BoxFit.cover)
                    : Container(color: AppColors.surface),
              ),
            ),
            const SizedBox(height: 16),
            if (photo.photographerName != null)
              Text(photo.photographerName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            if (photo.eventTitle != null) ...[
              const SizedBox(height: 2),
              Text(photo.eventTitle!, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            if (error != null) ...[
              Text(error, style: const TextStyle(color: AppColors.destructive), textAlign: TextAlign.center),
              const SizedBox(height: 8),
            ],
            if (photo.isPurchased)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('Sudah dibeli', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _purchasing ? null : _purchase,
                  child: _purchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Beli • ${formatCurrency(photo.price)}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
