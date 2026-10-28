import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/wallet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_address_provider.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton.dart';
import '../ads/ad_banner.dart';
import '../ads/admob.dart';
import '../cart/cart_providers.dart';
import '../orders/order_providers.dart';
import '../wallet/reward_effects.dart';
import '../wallet/wallet_providers.dart';
import 'ad_chest.dart';
import 'bonus_gift.dart';
import 'delivery_address_sheet.dart';
import 'home_popup.dart';
import 'home_providers.dart';
import 'welcome_message.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  final _locationKey = GlobalKey();
  final _searchKey = GlobalKey();
  int _selectedTab = 0;
  bool _defaultAddressAttempted = false;
  double _offset = 0;
  double _locationHeight = 50;
  double _searchHeight = 42;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
      if ((offset - _offset).abs() > 0.5) setState(() => _offset = offset.clamp(0.0, 400.0));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSetDefaultAddress());
    HomePopup.scheduleOn(this, ref);
  }

  /// First open with no saved address: default it to the user's current
  /// location. Tried once per home screen; failures are silent because the
  /// user can still pick an address by hand.
  Future<void> _maybeSetDefaultAddress() async {
    if (_defaultAddressAttempted || !mounted) return;
    final auth = ref.read(authProvider);
    final user = auth.user;
    if (auth.status != AuthStatus.authenticated || user == null || user.hasAddress) return;

    _defaultAddressAttempted = true;
    final applied = await ref.read(authProvider.notifier).setDefaultAddressFromLocation();
    if (!applied || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alamat pengiriman diatur sesuai lokasi Anda.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  double _measure(GlobalKey key, double current) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.size.height : current;
  }

  void _measureHeader() {
    final loc = _measure(_locationKey, _locationHeight);
    final search = _measure(_searchKey, _searchHeight);
    if ((loc - _locationHeight).abs() > 0.5 || (search - _searchHeight).abs() > 0.5) {
      setState(() {
        _locationHeight = loc;
        _searchHeight = search;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auth restores asynchronously (and users may log in from here), so the
    // initState check alone can run before the user is known.
    ref.listen<AuthState>(authProvider, (previous, next) => _maybeSetDefaultAddress());
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
    final hasActiveOrder = (ref.watch(activeOrdersProvider).valueOrNull ?? const []).isNotEmpty;

    final topPadding = MediaQuery.of(context).padding.top;
    final headerOpacity = ((_offset - (_locationHeight - 20)) / 40).clamp(0.0, 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureHeader();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                Future<void> silent(Future<void> future) => future.catchError((_) {});
                await Future.wait([
                  silent(ref.read(authProvider.notifier).checkBlockStatus()),
                  silent(ref.refresh(bannersProvider.future)),
                  silent(ref.refresh(rootCategoriesProvider.future)),
                  silent(ref.refresh(flashSaleProvider.future)),
                  silent(ref.refresh(bestSellersProvider.future)),
                  silent(ref.refresh(popularProductsProvider.future)),
                  silent(ref.refresh(walletProvider.future).then((_) {})),
                  silent(ref.refresh(adChestProvider.future).then((_) {})),
                ]);
              },
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                // Room for the floating active-order card only while it shows.
                padding: EdgeInsets.only(bottom: hasActiveOrder ? 90 : 16),
                children: [
                  // Top Header Backdrop (Brand green gradient + Petal pattern)
                  _HomeTopBackdrop(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topPadding + 6),
                        KeyedSubtree(key: _locationKey, child: _TopLocationHeader()),
                        SizedBox(height: 6 + _searchHeight + 6),

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
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Hadiah saldo belanja (one-time bonus), then Saldo E-Wallet
                  const BonusGiftBanner(),
                  // Promo: gratis ongkir untuk pembayaran pakai saldo belanja
                  const _WalletFreeShippingPromo(),
                  const SizedBox(height: 8),
                  const _WalletSection(),

                  const SizedBox(height: 8),

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

                  const SizedBox(height: 10),

                  // 6. Semua Kategori Grid (4 Columns Clean Pastel Cards)
                  categories.when(
                    data: (items) => items.isEmpty
                        ? const SizedBox.shrink()
                        : _CategoriesSection(categories: items),
                    loading: () => const _CategoryGridSkeleton(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  // Keeps the usual 28px gap when there is no ad.
                  const AdBanner(
                    placement: AdPlacement.home,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    emptyHeight: 28,
                  ),

                  // 7. Inspirasi Untukmu / Curated Product Feed with Tabs
                  _InspirasiUntukmuSection(
                    selectedTab: _selectedTab,
                    onTabChanged: (index) => setState(() => _selectedTab = index),
                    bestSellers: bestSellers.value ?? [],
                    popularProducts: popularProducts.value ?? [],
                    flashSaleProducts: flashSale.value?.slots.expand((s) => s.products).toList() ?? [],
                    loading: [bestSellers, popularProducts, flashSale].any((p) => p.isLoading && !p.hasValue),
                  ),

                  const AdBanner(
                    placement: AdPlacement.homeBottom,
                    padding: EdgeInsets.only(top: 16),
                  ),
                ],
              ),
            ),
            // Search bar: scrolls up with the page, then sticks to the top and turns solid
            Positioned(
              top: (_locationHeight - _offset).clamp(0.0, _locationHeight),
              left: 0,
              right: 0,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: headerOpacity),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15 * headerOpacity),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: topPadding + 6, bottom: 10),
                    child: KeyedSubtree(
                      key: _searchKey,
                      child: _TopSearchBar(cartItemCount: cartItemCount),
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

// ==========================================
// 1. TOP LOCATION & CS HEADER
// ==========================================
/// "Village, District, City" -> "Village, District" (the header leaves out
/// the city); null when there is no label.
String? _villageAndDistrict(String? label) {
  if (label == null) return null;
  return label.split(', ').take(2).join(', ');
}

class _TopLocationHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final guestAddress = ref.watch(guestAddressProvider);
    final failureLabel = locationFailureLabel(ref.watch(locationFailureProvider));
    final hasAddress = user != null ? user.hasAddress : guestAddress != null;
    final addressLine = user != null
        ? (user.hasAddress
            ? (_villageAndDistrict(user.addressLabel) ?? 'Alamat Utama (${user.name})')
            : (failureLabel ?? 'Atur Alamat Pengiriman'))
        : (_villageAndDistrict(guestAddress?.label) ??
            (failureLabel ?? 'Pilih Alamat Pengiriman'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Delivery Speed & Location
          Expanded(
            child: InkWell(
              onTap: () => showDeliveryAddressSheet(context),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  if (hasAddress) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showExpressInfoDialog(context),
                    child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 4, 9, 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ExpressCarIcon(),
                        SizedBox(width: 3),
                        Text(
                          '15 Menit',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF78350F),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dikirim ke',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.2,
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                addressLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
                          ],
                        ),
                      ],
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

/// Stopwatch icon with looping speed lines streaming out behind it ("express" feel).
void _showAboutAppDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/logo_mark.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Inovasi Online',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Text(
                  info == null ? ' ' : 'Versi ${info.version} (${info.buildNumber})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                );
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Aplikasi belanja online dengan pengiriman instan dari toko terdekat '
              'langsung ke alamatmu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.code_rounded, size: 20, color: Color(0xFFF59E0B)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dibuat oleh',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        Text(
                          'Rio Susanto',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '© ${DateTime.now().year} Inovasi Online. Hak cipta dilindungi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showExpressInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.bolt, color: Color(0xFF78350F), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Pengiriman Instan 15 Menit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pesananmu bisa sampai dalam estimasi 15 menit sejak pesanan dikonfirmasi, '
            'karena dikirim dari toko terdekat dengan alamat pengirimanmu.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
          SizedBox(height: 12),
          _ExpressInfoPoint(
            icon: Icons.location_on_outlined,
            text: 'Berlaku untuk alamat yang berada dalam jangkauan layanan instan.',
          ),
          _ExpressInfoPoint(
            icon: Icons.schedule,
            text: 'Waktu tiba adalah estimasi dan dapat berubah karena cuaca, lalu lintas, atau antrean pesanan.',
          ),
          _ExpressInfoPoint(
            icon: Icons.local_shipping_outlined,
            text: 'Pilih opsi Instan 15 Menit atau Reguler saat checkout.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}

class _ExpressInfoPoint extends StatelessWidget {
  const _ExpressInfoPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ExpressCarIcon extends StatefulWidget {
  const _ExpressCarIcon();

  @override
  State<_ExpressCarIcon> createState() => _ExpressCarIconState();
}

class _ExpressCarIconState extends State<_ExpressCarIcon>
    with SingleTickerProviderStateMixin {
  static const _ink = Color(0xFF78350F);
  // (vertical offset, line width, phase offset 0..1)
  static const _lines = [
    (-5.0, 6.0, 0.0),
    (0.0, 9.0, 0.35),
    (5.0, 5.0, 0.7),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (final (dy, width, phase) in _lines)
                Builder(builder: (context) {
                  final p = (t + phase) % 1.0;
                  return Positioned(
                    left: 12 - p * 12,
                    top: 9 + dy - 0.75,
                    child: Opacity(
                      opacity: (1 - p).clamp(0.0, 1.0),
                      child: Container(
                        width: width,
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: _ink,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  );
                }),
              Positioned(
                right: 0,
                top: 0.5,
                child: const Icon(Icons.timer_outlined, size: 17, color: _ink),
              ),
            ],
          );
        },
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
          // Logo Mark
          GestureDetector(
            onTap: () => _showAboutAppDialog(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo_mark.png',
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/search'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 20, color: AppColors.primary),
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
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.shopping_bag_rounded, size: 22, color: Color(0xFF115E59)),
                  if (cartItemCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
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
                            height: 1,
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
// TOP HEADER BACKDROP WITH PETAL PATTERN
// ==========================================
class _HomeTopBackdrop extends StatelessWidget {
  const _HomeTopBackdrop({required this.child});

  final Widget child;

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
                    AppColors.primary.withValues(alpha: 0.60),
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
          bottom: 50,
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
        child,
      ],
    );
  }

  static Widget _decorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

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

// ==========================================
// 3. SALDO E-WALLET (Saldo Belanja)
// ==========================================
class _WalletSection extends ConsumerStatefulWidget {
  const _WalletSection();

  @override
  ConsumerState<_WalletSection> createState() => _WalletSectionState();
}

class _WalletSectionState extends ConsumerState<_WalletSection> {
  static const _gradient = [Color(0xFF0D9488), Color(0xFF0284C7)];

  @override
  Widget build(BuildContext context) {
    final authenticated = ref.watch(
      authProvider.select((s) => s.status == AuthStatus.authenticated),
    );
    final wallet = ref.watch(walletProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _gradient.last.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _gradient,
                ),
              ),
              child: Stack(
                children: [
                  // Decorative bubbles
                  Positioned(right: -30, top: -50, child: _bubble(110, 0.10)),
                  Positioned(right: 80, bottom: -50, child: _bubble(80, 0.07)),
                  Positioned(left: -20, bottom: -34, child: _bubble(56, 0.06)),
                  authenticated
                      ? _signedIn(wallet)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: _signedOut(),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _bubble(double size, double alpha) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha),
          ),
        ),
      );

  static Widget _iconBadge(IconData icon) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      );

  Widget _signedIn(AsyncValue<WalletSummary?> wallet) {
    final hidden = ref.watch(walletBalanceHiddenProvider);
    final summary = wallet.valueOrNull;
    final Widget balance;
    if (wallet.isLoading && !wallet.hasValue) {
      balance = Container(
        width: 100,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    } else {
      balance = _CountUpBalance(
        amount: ref.watch(walletBalanceHoldProvider) ?? summary?.balance,
        hidden: hidden,
      );
    }

    final balanceRow = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label with the mask toggle beside it, so the figure gets the full width.
              InkWell(
                onTap: () => ref.read(walletBalanceHiddenProvider.notifier).toggle(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 13, color: Colors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 5),
                      Text(
                        'Saldo Belanja',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 0),
              KeyedSubtree(key: walletBalanceTargetKey, child: balance),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _WalletAction(
          icon: Icons.add_rounded,
          label: 'Top Up',
          primary: true,
          onTap: () => context.push('/wallet/topup'),
        ),
        const SizedBox(width: 6),
        _WalletAction(
          icon: Icons.receipt_long_rounded,
          label: 'Riwayat',
          onTap: () => context.push('/wallet'),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          balanceRow,
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 11, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Saldo tidak dapat dicairkan atau ditransfer ke rekening bank',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
          // Its own row, last: a game, not a money action like Top Up / Riwayat.
          const AdChestWalletStrip(),
        ],
      ),
    );
  }

  Widget _signedOut() {
    return Row(
      children: [
        _iconBadge(Icons.card_giftcard_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE047),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'BONUS PENGGUNA BARU',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF713F12),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Daftar untuk mendapatkan bonus Saldo Belanja!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () => context.push('/account/register'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _gradient.last,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            minimumSize: const Size(0, 36),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          child: const Text('Daftar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

/// Balance figure that counts up (with a gold pulse) whenever it increases,
/// e.g. when the bonus coin lands.
class _CountUpBalance extends StatefulWidget {
  const _CountUpBalance({required this.amount, required this.hidden});

  final double? amount;
  final bool hidden;

  @override
  State<_CountUpBalance> createState() => _CountUpBalanceState();
}

class _CountUpBalanceState extends State<_CountUpBalance> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  double? _from;

  @override
  void didUpdateWidget(covariant _CountUpBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.amount, after = widget.amount;
    if (before != null && after != null && after > before) {
      _from = before;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final amount = widget.amount;
        final t = Curves.easeOutCubic.transform(_controller.value);
        final pulse = math.sin(_controller.value * math.pi);
        final shown = amount == null ? null : (_from ?? amount) + (amount - (_from ?? amount)) * t;

        return Transform.scale(
          scale: 1 + pulse * 0.12,
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              shown == null ? '—' : (widget.hidden ? 'Rp ••••••' : formatCurrency(shown.roundToDouble())),
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color.lerp(Colors.white, const Color(0xFFFDE047), pulse),
                letterSpacing: -0.3,
                shadows: pulse > 0
                    ? [Shadow(color: const Color(0xFFFDE047).withValues(alpha: 0.7 * pulse), blurRadius: 12)]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Solid white (Top Up); the rest stay translucent.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: primary ? Colors.white : Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: primary ? null : Border.all(color: Colors.white.withValues(alpha: 0.35)),
                boxShadow: primary
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Icon(icon, size: 16, color: primary ? const Color(0xFF0284C7) : Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
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
            height: ProductGridDelegate.tileHeight(
              154,
              MediaQuery.textScalerOf(context).scale(1),
            ),
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
// PROMO GRATIS ONGKIR (Bayar pakai Saldo Belanja)
// ==========================================
class _WalletFreeShippingPromo extends StatelessWidget {
  const _WalletFreeShippingPromo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: Colors.white, size: 13),
            SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Gratis Ongkir ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: 'untuk pembayaran pakai Saldo Belanja'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kategori Pilihan',
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
          ),
          const SizedBox(height: 15),

          // 4 Columns Grid
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final cat = displayCategories[index];
              final bg = _pastelBgs[index % _pastelBgs.length];

              return InkWell(
                onTap: () => context.push('/categories/${cat.slug}', extra: cat.name),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          cat.listImageUrl != null && cat.listImageUrl!.isNotEmpty
                              ? CachedNetworkImage(memCacheWidth: 300, imageUrl: cat.listImageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const Center(
                                    child: Icon(Icons.image_outlined, size: 26, color: Color(0xFF94A3B8)),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.image_outlined, size: 26, color: Color(0xFF94A3B8)),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
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
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                cat.listImageUrl != null
                                    ? CachedNetworkImage(memCacheWidth: 300, imageUrl: cat.listImageUrl!, fit: BoxFit.cover)
                                    : const Center(child: Icon(Icons.image_outlined, size: 24, color: Color(0xFF94A3B8))),
                                    ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
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
    required this.loading,
  });

  final int selectedTab;
  /// Product lists still on their first load: show tile skeletons, not the empty text.
  final bool loading;
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
          if (activeProducts.isEmpty && loading)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: ProductGridDelegate(
                textScale: MediaQuery.textScalerOf(context).scale(1),
              ),
              itemBuilder: (_, _) => const ProductTileSkeleton(),
            )
          else if (activeProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Belum ada produk pilihan.'),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeProducts.length,
              gridDelegate: ProductGridDelegate(
                textScale: MediaQuery.textScalerOf(context).scale(1),
              ),
              itemBuilder: (context, index) {
                final product = activeProducts[index];
                return ProductCard(
                  product: product,
                  compact: true,
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

/// Mirrors [_CategoriesSection]'s layout (paddings, grid, tile sizes, 12 tiles)
/// so nothing shifts when the categories arrive.
class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Skeleton(height: 20, width: 130),
          ),
          const SizedBox(height: 15),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (_, _) => const Column(
              children: [
                Skeleton(width: 66, height: 66, borderRadius: 16),
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
