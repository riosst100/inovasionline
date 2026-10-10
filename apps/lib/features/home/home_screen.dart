import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/skeleton.dart';
import 'home_providers.dart';
import 'user_summary_card.dart';
import 'welcome_message.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  double _headerOpacity = 0;

  static const double _headerFadeDistance = 120;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final opacity = (_scrollController.offset / _headerFadeDistance).clamp(0.0, 1.0);
    if (opacity != _headerOpacity) {
      setState(() => _headerOpacity = opacity);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WelcomeMessage?>(pendingWelcomeProvider, (previous, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.text),
          backgroundColor: next.type == WelcomeType.logout ? AppColors.foreground : AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      Future.microtask(() => ref.read(pendingWelcomeProvider.notifier).state = null);
    });

    final banners = ref.watch(bannersProvider);
    final categories = ref.watch(rootCategoriesProvider);
    final flashSale = ref.watch(flashSaleProvider);
    final bestSellers = ref.watch(bestSellersProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _HomeHeader(opacity: _headerOpacity),
      ),
      body: RefreshIndicator(
        edgeOffset: MediaQuery.of(context).padding.top + 64,
        onRefresh: () async {
          Future<void> silent(Future<void> future) => future.catchError((_) {});
          await Future.wait([
            silent(ref.refresh(bannersProvider.future)),
            silent(ref.refresh(rootCategoriesProvider.future)),
            silent(ref.refresh(flashSaleProvider.future)),
            silent(ref.refresh(bestSellersProvider.future)),
          ]);
        },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            _HomeTopBackdrop(
              topInset: MediaQuery.of(context).padding.top + 64,
              bannerHeight: 140,
              banner: banners.when(
                data: (items) => items.isEmpty ? const SizedBox.shrink() : BannerCarousel(banners: items),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Skeleton(height: 140, borderRadius: 12),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
              child: const UserSummaryCard(),
            ),
            const SizedBox(height: 20),
            const _SubFeatureRow(),
            const SizedBox(height: 20),
            categories.when(
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : _CategoryGrid(categories: items),
              loading: () => SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, _) => const Column(
                    children: [
                      Skeleton(width: 60, height: 60, borderRadius: 12),
                      SizedBox(height: 8),
                      Skeleton(width: 50, height: 12),
                    ],
                  ),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            flashSale.when(
              data: (schedule) {
                final activeSlot = schedule.slots.where((s) => s.isActive).firstOrNull ??
                    schedule.slots.where((s) => s.isUpcoming).firstOrNull;

                if (activeSlot == null || activeSlot.products.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt, color: AppColors.primary, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Flash Sale ${activeSlot.label}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                            ],
                          ),
                          TextButton(onPressed: () => context.push('/flash-sale'), child: const Text('Lihat Semua')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: activeSlot.products.length,
                        itemBuilder: (context, index) {
                          final product = activeSlot.products[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: 148,
                              child: _ProductTile(
                                product: product,
                                badgeIcon: Icons.bolt,
                                badgeLabel: 'Flash Sale',
                                onTap: () => context.push('/products/${product.slug}'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, _) => const SizedBox(width: 148, child: ProductTileSkeleton()),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: AppColors.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Produk Terlaris',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            bestSellers.when(
              data: (items) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.66,
                ),
                itemBuilder: (context, index) {
                  final product = items[index];
                  return _ProductTile(
                    product: product,
                    badgeIcon: Icons.trending_up,
                    badgeLabel: 'Terlaris',
                    onTap: () => context.push('/products/${product.slug}'),
                  );
                },
              ),
              loading: () => const ProductGridSkeleton(shrinkWrap: true),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Gagal memuat produk: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: opacity),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity,
                child: const RepaintBoundary(
                  child: CustomPaint(painter: _PetalPatternPainter()),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'assets/images/logo_mark.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => context.push('/search'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Cari produk...',
                                style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                              ),
                            ),
                            const Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.mutedForeground),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                      onPressed: () => context.push('/cart'),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Repeating four-petal motif drawn in code (no image asset), used as a
/// subtle decorative overlay on the green header/backdrop.
class _PetalPatternPainter extends CustomPainter {
  const _PetalPatternPainter({this.opacity = 0.12}) : color = Colors.white;

  final Color color;
  final double opacity;

  static const double _tile = 56;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final cols = (size.width / _tile).ceil() + 1;
    final rows = (size.height / _tile).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final center = Offset(col * _tile, row * _tile);
        _drawPetals(canvas, paint, center, _tile * 0.42);
      }
    }
  }

  void _drawPetals(Canvas canvas, Paint paint, Offset center, double radius) {
    for (var i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final path = Path();
      final petalTip = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      path.moveTo(center.dx, center.dy);
      path.quadraticBezierTo(
        center.dx + radius * 0.55 * math.cos(angle - 0.5),
        center.dy + radius * 0.55 * math.sin(angle - 0.5),
        petalTip.dx,
        petalTip.dy,
      );
      path.quadraticBezierTo(
        center.dx + radius * 0.55 * math.cos(angle + 0.5),
        center.dy + radius * 0.55 * math.sin(angle + 0.5),
        center.dx,
        center.dy,
      );
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}

/// Green gradient backdrop behind the member summary card and the top half
/// of the banner, so the homepage isn't flat white. Fades out to transparent
/// by the banner's midpoint; rest of the page stays plain white.
class _HomeTopBackdrop extends StatelessWidget {
  const _HomeTopBackdrop({
    required this.topInset,
    required this.child,
    required this.banner,
    required this.bannerHeight,
  });

  final double topInset;
  final Widget child;
  final Widget banner;
  final double bannerHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.95),
                    AppColors.primary.withValues(alpha: 0.92),
                    AppColors.primary.withValues(alpha: 0.85),
                    AppColors.primary.withValues(alpha: 0.74),
                    AppColors.primary.withValues(alpha: 0.6),
                    AppColors.primary.withValues(alpha: 0.46),
                    AppColors.primary.withValues(alpha: 0.33),
                    AppColors.primary.withValues(alpha: 0.21),
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.05),
                    AppColors.primary.withValues(alpha: 0.0),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.25, 0.38, 0.48, 0.57, 0.65, 0.72, 0.78, 0.83, 0.87, 0.9, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + 180,
          child: const IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _PetalPatternPainter(opacity: 0.1)),
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -30,
          child: IgnorePointer(child: _decorativeCircle(90, Colors.white.withValues(alpha: 0.10))),
        ),
        Positioned(
          top: 20,
          left: -50,
          child: IgnorePointer(child: _decorativeCircle(120, Colors.white.withValues(alpha: 0.08))),
        ),
        Column(
          children: [
            SizedBox(height: topInset + 12),
            child,
            const SizedBox(height: 8),
            banner,
          ],
        ),
      ],
    );
  }

  Widget _decorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SubFeatureRow extends StatelessWidget {
  const _SubFeatureRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _SubFeatureCard(
              label: 'DelivBae',
              subtitle: 'Segera hadir',
              icon: Icons.delivery_dining,
              color: AppColors.primary,
              onTap: () => _showComingSoon(context, 'DelivBae'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SubFeatureCard(
              label: 'PotoCandid',
              subtitle: 'Cari fotomu',
              icon: Icons.camera_alt,
              color: AppColors.foreground,
              onTap: () => context.push('/potocandid'),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName segera hadir'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SubFeatureCard extends StatelessWidget {
  const _SubFeatureCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.foreground.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
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

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<Category> categories;

  static const int _perPage = 4;

  @override
  Widget build(BuildContext context) {
    final pageCount = (categories.length / _perPage).ceil();

    return SizedBox(
      height: 116,
      child: PageView.builder(
        padEnds: false,
        itemCount: pageCount,
        itemBuilder: (context, pageIndex) {
          final start = pageIndex * _perPage;
          final end = math.min(start + _perPage, categories.length);
          final pageCategories = categories.sublist(start, end);

          return Padding(
            padding: EdgeInsets.only(left: pageIndex == 0 ? 16 : 8, right: 8),
            child: Row(
              children: [
                for (final category in pageCategories)
                  Expanded(
                    child: InkWell(
                      onTap: () => context.push('/categories/${category.slug}', extra: category.name),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: category.icon != null && category.icon!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: category.icon!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        const Icon(Icons.grid_view_rounded, color: AppColors.foreground, size: 26),
                                  )
                                : const Icon(Icons.grid_view_rounded, color: AppColors.foreground, size: 26),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.badgeIcon,
    required this.badgeLabel,
  });

  final Product product;
  final VoidCallback onTap;
  final IconData badgeIcon;
  final String badgeLabel;

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
                    child: product.imageUrl != null
                        ? CachedNetworkImage(imageUrl: product.imageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.image_outlined, color: AppColors.mutedForeground),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            badgeLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.25),
                        ),
                        if (product.storeName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.storeName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCurrency(product.displayPrice),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                        if (product.soldCount > 0)
                          Text(
                            '${product.soldCount} terjual',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.mutedForeground),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
