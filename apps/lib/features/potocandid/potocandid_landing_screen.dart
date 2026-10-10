import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../widgets/skeleton.dart';
import 'photo_card.dart';
import 'photo_detail_sheet.dart';
import 'potocandid_providers.dart';

class PotoCandidLandingScreen extends ConsumerStatefulWidget {
  const PotoCandidLandingScreen({super.key});

  @override
  ConsumerState<PotoCandidLandingScreen> createState() => _PotoCandidLandingScreenState();
}

class _PotoCandidLandingScreenState extends ConsumerState<PotoCandidLandingScreen> {
  bool _checkedFaceProfile = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await ref.read(potoCandidProvider.notifier).loadFaceProfileStatus();
    if (!mounted) return;

    setState(() => _checkedFaceProfile = true);

    final hasProfile = ref.read(potoCandidProvider).hasFaceProfile;
    if (!hasProfile) {
      await context.push('/potocandid/selfie');
      if (!mounted) return;
      ref.read(potoCandidProvider.notifier).loadFaceProfileStatus();
    }

    ref.read(potoCandidProvider.notifier).loadBrowsePhotos();
    ref.read(potoCandidProvider.notifier).loadMatchedPhotos();
    ref.read(potoCandidProvider.notifier).loadPurchases();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedFaceProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PotoCandid'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Jelajahi'), Tab(text: 'Foto Saya')],
          ),
        ),
        body: const TabBarView(
          children: [_BrowseTab(), _MyPhotosTab()],
        ),
      ),
    );
  }
}

class _BrowseTab extends ConsumerWidget {
  const _BrowseTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(potoCandidProvider);

    if (state.browseLoading) return const ProductGridSkeleton();

    if (state.browsePhotos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada foto yang diunggah.', style: TextStyle(color: AppColors.mutedForeground)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.browsePhotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final photo = state.browsePhotos[index];
        return PhotoCard(photo: photo, onTap: () => showPhotoDetailSheet(context, photo));
      },
    );
  }
}

class _MyPhotosTab extends ConsumerWidget {
  const _MyPhotosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(potoCandidProvider);
    final items = [...state.matchedPhotos, ...state.purchasedPhotos];

    if (state.matchedLoading || state.purchasesLoading) return const ProductGridSkeleton();

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada foto yang cocok atau dibeli.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final photo = items[index];
        return PhotoCard(photo: photo, onTap: () => showPhotoDetailSheet(context, photo));
      },
    );
  }
}
