import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../widgets/skeleton.dart';
import 'photo_card.dart';
import 'photo_detail_sheet.dart';
import 'potocandid_providers.dart';

class MatchedPhotosScreen extends ConsumerStatefulWidget {
  const MatchedPhotosScreen({super.key});

  @override
  ConsumerState<MatchedPhotosScreen> createState() => _MatchedPhotosScreenState();
}

class _MatchedPhotosScreenState extends ConsumerState<MatchedPhotosScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(potoCandidProvider.notifier).loadMatchedPhotos());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(potoCandidProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Foto Cocok')),
      body: state.matchedLoading
          ? const ProductGridSkeleton()
          : state.matchedPhotos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Belum ada foto yang cocok dengan wajahmu. Coba lagi nanti setelah fotografer mengunggah foto baru.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.matchedPhotos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final photo = state.matchedPhotos[index];
                    return PhotoCard(photo: photo, onTap: () => showPhotoDetailSheet(context, photo));
                  },
                ),
    );
  }
}
