import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton.dart';
import '../cart/cart_providers.dart';
import 'home_providers.dart';
import 'welcome_message.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  int _selectedTab = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WelcomeMessage?>(pendingWelcomeProvider, (previous, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.text),
          backgroundColor: next.type == WelcomeType.logout ? AppColors.foreground : const Color(0xFF0284C7),
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
    final popularProducts = ref.watch(popularProductsProvider);
    final cartState = ref.watch(cartProvider);
    final cartItemCount = cartState.cart?.itemCount ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: const Color(0xFF0284C7),
              onRefresh: () async {
                Future<void> silent(Future<void> future) => future.catchError((_) {});
                await Future.wait([
                  silent(ref.refresh(bannersProvider.future)),
                  silent(ref.refresh(rootCategoriesProvider.future)),
                  silent(ref.refresh(flashSaleProvider.future)),
                  silent(ref.refresh(bestSellersProvider.future)),
                  silent(ref.refresh(popularProductsProvider.future)),
                ]);
              },
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  // 1. Top Bar: Quick Delivery ETA, Address Dropdown & Chat CS
                  _TopLocationHeader(),

                  // 2. Modern White Search Bar
                  _TopSearchBar(cartItemCount: cartItemCount),

                  const SizedBox(height: 14),

                  // 3. Hero Promo Banner Carousel
                  banners.when(
                    data: (items) => items.isEmpty
                        ? const SizedBox.shrink()
                        : BannerCarousel(banners: items),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Skeleton(height: 156, borderRadius: 16),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 18),

                  // 4. Quick Highlight Bubbles (Astro-style 4 highlights)
                  const _QuickHighlightsRow(),

                  const SizedBox(height: 22),

                  // 5. Promo Gercep (Flash Sale with Live Countdown Timer)
                  flashSale.when(
                    data: (schedule) {
                      final activeSlot = schedule.slots.where((s) => s.isActive).firstOrNull ??
                          schedule.slots.where((s) => s.isUpcoming).firstOrNull;

                      if (activeSlot == null || activeSlot.products.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return _PromoGercepSection(
                        slotLabel: activeSlot.label,
                        products: activeSlot.products,
                        endsAt: activeSlot.endsAt,
                      );
                    },
                    loading: () => const _SectionSkeleton(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  // 6. Semua Kategori Grid (4 Columns Clean Pastel Cards)
                  categories.when(
                    data: (items) => items.isEmpty
                        ? const SizedBox.shrink()
                        : _CategoriesSection(categories: items),
                    loading: () => const _CategoryGridSkeleton(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 28),

                  // 7. Inspirasi Untukmu / Curated Product Feed with Tabs
                  _InspirasiUntukmuSection(
                    selectedTab: _selectedTab,
                    onTabChanged: (index) => setState(() => _selectedTab = index),
                    bestSellers: bestSellers.value ?? [],
                    popularProducts: popularProducts.value ?? [],
                    flashSaleProducts: flashSale.value?.slots.expand((s) => s.products).toList() ?? [],
                  ),
                ],
              ),
            ),

            // Persistent Floating Free Shipping Pill Bar (Above Navigation Bar)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: _FloatingFreeShippingBar(
                onTap: () => context.push('/cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. TOP LOCATION & CS HEADER
// ==========================================
class _TopLocationHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final addressLine = user != null
        ? (user.hasAddress ? 'Alamat Utama (${user.name})' : 'Atur Alamat Pengiriman')
        : 'Pilih Alamat Pengiriman';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Delivery Speed & Location
          Expanded(
            child: InkWell(
              onTap: () {
                if (user == null) {
                  context.push('/account/login');
                } else {
                  context.push('/complete-address');
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 14, color: Color(0xFF0284C7)),
                        SizedBox(width: 2),
                        Text(
                          '15 Menit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cepat sampai',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                addressLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chat CS Button Pill
          InkWell(
            onTap: () => context.push('/chat'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headset_mic_outlined, size: 15, color: Color(0xFF334155)),
                  SizedBox(width: 5),
                  Text(
                    'Chat CS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
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

// ==========================================
// 2. MODERN SEARCH BAR
// ==========================================
class _TopSearchBar extends StatelessWidget {
  const _TopSearchBar({required this.cartItemCount});

  final int cartItemCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/search'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lagi cari apa? Semua Lengkap di sini',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Cart Shortcut with Badge
          InkWell(
            onTap: () => context.push('/cart'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 20, color: Color(0xFF334155)),
                  if (cartItemCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          cartItemCount > 99 ? '99+' : '$cartItemCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

// ==========================================
// 3. QUICK HIGHLIGHTS ROW (Astro Feature Bubbles)
// ==========================================
class _QuickHighlightsRow extends StatelessWidget {
  const _QuickHighlightsRow();

  static const _highlights = [
    {
      'title': 'GRATIS Ongkir',
      'subtitle': 'Pasti Hemat',
      'icon': Icons.local_shipping_outlined,
      'color': Color(0xFFE0F2FE),
      'textColor': Color(0xFF0369A1),
    },
    {
      'title': 'Juaranya Buah',
      'subtitle': 'Manis Segar',
      'icon': Icons.eco_outlined,
      'color': Color(0xFFFEF3C7),
      'textColor': Color(0xFFB45309),
    },
    {
      'title': 'Paket Dapur',
      'subtitle': 'Sembako Murah',
      'icon': Icons.shopping_basket_outlined,
      'color': Color(0xFFF0FDF4),
      'textColor': Color(0xFF15803D),
    },
    {
      'title': 'Flash 15m',
      'subtitle': 'Cepat Sampai',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFFFDF2F8),
      'textColor': Color(0xFFBE185D),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _highlights.map((item) {
          final color = item['color'] as Color;
          final textColor = item['textColor'] as Color;
          final icon = item['icon'] as IconData;
          final title = item['title'] as String;
          final subtitle = item['subtitle'] as String;

          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: textColor, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// 4. PROMO GERCEP (Flash Sale with Countdown)
// ==========================================
class _PromoGercepSection extends StatefulWidget {
  const _PromoGercepSection({
    required this.slotLabel,
    required this.products,
    this.endsAt,
  });

  final String slotLabel;
  final List<Product> products;
  final DateTime? endsAt;

  @override
  State<_PromoGercepSection> createState() => _PromoGercepSectionState();
}

class _PromoGercepSectionState extends State<_PromoGercepSection> {
  Timer? _countdownTimer;
  Duration _timeLeft = const Duration(hours: 1, minutes: 24, seconds: 35);

  @override
  void initState() {
    super.initState();
    _initTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_timeLeft.inSeconds > 0) {
        setState(() => _timeLeft = _timeLeft - const Duration(seconds: 1));
      }
    });
  }

  void _initTime() {
    if (widget.endsAt != null) {
      final diff = widget.endsAt!.difference(DateTime.now());
      if (diff.isNegative) {
        _timeLeft = Duration.zero;
      } else {
        _timeLeft = diff;
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDigit(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final hours = _formatDigit(_timeLeft.inHours % 24);
    final minutes = _formatDigit(_timeLeft.inMinutes % 60);
    final seconds = _formatDigit(_timeLeft.inSeconds % 60);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F9FF), // Soft sky blue container
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title, Countdown & See All
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFF0284C7), size: 24),
                    const SizedBox(width: 4),
                    const Text(
                      'Promo Gercep',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live Countdown Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$hours : $minutes : $seconds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => context.push('/flash-sale'),
                  child: const Text(
                    'Lihat semua',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Horizontal Flash Sale Cards
          SizedBox(
            height: 258,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = widget.products[index];
                return SizedBox(
                  width: 154,
                  child: ProductCard(
                    product: product,
                    badgeText: 'Diskon',
                    onTap: () => context.push('/products/${product.slug}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. SEMUA KATEGORI (Clean 4-Column Grid)
// ==========================================
class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.categories});

  final List<Category> categories;

  static const _pastelBgs = [
    Color(0xFFFEF3C7), // warm amber
    Color(0xFFDCFCE7), // soft mint green
    Color(0xFFFEE2E2), // soft peach/red
    Color(0xFFE0F2FE), // soft sky
    Color(0xFFEDE9FE), // soft lavender
    Color(0xFFFCE7F3), // soft rose
    Color(0xFFFEF9C3), // soft yellow
    Color(0xFFE2E8F0), // clean slate
  ];

  @override
  Widget build(BuildContext context) {
    // Show up to 12 categories
    final displayCategories = categories.take(12).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Semua Kategori',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (categories.length > 12)
                InkWell(
                  onTap: () => _showAllCategoriesSheet(context),
                  child: Text(
                    'Lihat (${categories.length}) >',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Columns Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              final cat = displayCategories[index];
              final bg = _pastelBgs[index % _pastelBgs.length];

              return InkWell(
                onTap: () => context.push('/categories/${cat.slug}', extra: cat.name),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: cat.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Center(
                                child: Text(cat.icon ?? '🛒', style: const TextStyle(fontSize: 26)),
                              ),
                            )
                          : Center(
                              child: Text(cat.icon ?? '🛒', style: const TextStyle(fontSize: 26)),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAllCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Semua Kategori Produk',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/categories/${cat.slug}', extra: cat.name);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: cat.imageUrl != null
                                ? CachedNetworkImage(imageUrl: cat.imageUrl!, fit: BoxFit.cover)
                                : Center(child: Text(cat.icon ?? '🛒', style: const TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 6. INSPIRASI UNTUKMU (Curated Feed with Tabs)
// ==========================================
class _InspirasiUntukmuSection extends StatelessWidget {
  const _InspirasiUntukmuSection({
    required this.selectedTab,
    required this.onTabChanged,
    required this.bestSellers,
    required this.popularProducts,
    required this.flashSaleProducts,
  });

  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final List<Product> bestSellers;
  final List<Product> popularProducts;
  final List<Product> flashSaleProducts;

  static const _tabItems = [
    {'title': 'Special For You', 'icon': '✨'},
    {'title': 'Produk Terbaik', 'icon': '🔥'},
    {'title': 'Promo Kilat', 'icon': '⚡'},
    {'title': 'Produk Terbaru', 'icon': '🆕'},
  ];

  @override
  Widget build(BuildContext context) {
    // Resolve products for active tab
    List<Product> activeProducts;
    switch (selectedTab) {
      case 1:
        activeProducts = bestSellers.isNotEmpty ? bestSellers : popularProducts;
        break;
      case 2:
        activeProducts = flashSaleProducts.isNotEmpty ? flashSaleProducts : bestSellers;
        break;
      case 3:
        activeProducts = popularProducts.isNotEmpty ? popularProducts : bestSellers;
        break;
      default:
        // Special For You combines popular & best sellers
        activeProducts = popularProducts.isNotEmpty ? popularProducts : bestSellers;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inspirasi Untukmu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal Tab Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_tabItems.length, (index) {
                final tab = _tabItems[index];
                final isSelected = selectedTab == index;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onTabChanged(index),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(tab['icon']!, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            tab['title']!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // 2-Column Responsive Product Grid
          if (activeProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Memuat produk pilihan...'),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemBuilder: (context, index) {
                final product = activeProducts[index];
                return ProductCard(
                  product: product,
                  badgeText: selectedTab == 1 ? 'Terlaris' : 'Premium',
                  onTap: () => context.push('/products/${product.slug}'),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. FLOATING FREE SHIPPING BAR (Astro Sticky Banner)
// ==========================================
class _FloatingFreeShippingBar extends StatelessWidget {
  const _FloatingFreeShippingBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Belanja Rp35rb lagi, ada Gratis Ongkir!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SKELETON LOADERS
// ==========================================
class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 20, width: 140),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const Skeleton(width: 140, height: 200, borderRadius: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 20, width: 130),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (_, _) => const Column(
              children: [
                Skeleton(width: 60, height: 60, borderRadius: 16),
                SizedBox(height: 6),
                Skeleton(width: 48, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
