import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/potocandid_photo.dart';

class PhotoCard extends StatelessWidget {
  const PhotoCard({super.key, required this.photo, required this.onTap});

  final PotoCandidPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.surface,
                    child: photo.displayUrl != null
                        ? CachedNetworkImage(
                            imageUrl: photo.displayUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.surface),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.image_not_supported_outlined, color: AppColors.mutedForeground),
                          )
                        : const Icon(Icons.image_outlined, color: AppColors.mutedForeground),
                  ),
                  if (!photo.isPurchased)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.lock_outline, size: 14, color: Colors.white),
                      ),
                    ),
                  if (photo.isMatched)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Cocok',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photo.photographerName != null)
                    Text(
                      photo.photographerName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    photo.isPurchased ? 'Sudah dibeli' : formatCurrency(photo.price),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: photo.isPurchased ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
