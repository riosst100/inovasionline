import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/wallet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/reduce_motion_loop.dart';
import '../ads/admob.dart';
import '../wallet/reward_effects.dart';
import '../wallet/wallet_providers.dart';
import 'bonus_gift.dart';

const _violet = Color(0xFF7C3AED);
const _indigo = Color(0xFF4F46E5);
const _wood = Color(0xFF92400E);
const _woodDark = Color(0xFF5B2A0A);

/// Shakes now and then, like the bonus gift: a quick rattle at the start of
/// every [controller] cycle, then rest.
double _rattleAngle(double t, {double strength = 0.14}) =>
    t < 0.25 ? math.sin(t * 4 * math.pi * 4) * strength * (1 - t * 4) : 0.0;

/// "Peti Hadiah" row inside the home saldo card, under the balance and apart
/// from Top Up / Riwayat: a rattling chest, how many chests are left today and
/// a "Buka" pill. Opens the chest page. Hidden while admin has the chests off.
class AdChestWalletStrip extends ConsumerStatefulWidget {
  const AdChestWalletStrip({super.key});

  @override
  ConsumerState<AdChestWalletStrip> createState() => _AdChestWalletStripState();
}

class _AdChestWalletStripState extends ConsumerState<AdChestWalletStrip> with SingleTickerProviderStateMixin, ReduceMotionLoop {
  late final _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  AnimationController get loopController => _wiggle;

  /// The rattle is the first quarter of the cycle (see [_rattleAngle]); the rest is idle.
  @override
  double get loopActiveFraction => 0.25;

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(adChestProvider).valueOrNull;
    if (status == null) return const SizedBox.shrink();
    final left = status.canOpen ? status.remaining : 0;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.push('/chest'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
            child: Row(
              children: [
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _wiggle,
                    builder: (_, child) => Transform.rotate(
                      angle: left > 0 ? _rattleAngle(_wiggle.value) : 0,
                      child: child,
                    ),
                    child: const SizedBox(width: 24, height: 20, child: FittedBox(child: TreasureChest())),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Peti Hadiah',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    left > 0 ? '$left peti siap dibuka' : 'Kembali lagi besok',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                if (left > 0)
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                    decoration: BoxDecoration(color: rewardGold, borderRadius: BorderRadius.circular(99)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Buka', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: rewardBrown)),
                        Icon(Icons.chevron_right_rounded, size: 15, color: rewardBrown),
                      ],
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's chests (admin: Iklan > Peti Hadiah). Tapping a closed chest plays a
/// rewarded ad; once it is watched to the end the chest opens like the
/// new-user bonus and its saldo belanja lands in the balance.
class AdChestScreen extends ConsumerStatefulWidget {
  const AdChestScreen({super.key});

  @override
  ConsumerState<AdChestScreen> createState() => _AdChestScreenState();
}

class _AdChestScreenState extends ConsumerState<AdChestScreen> with SingleTickerProviderStateMixin {
  late final _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  bool _busy = false;

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_busy) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    setState(() => _busy = true);

    try {
      final ads = ref.read(rewardedAdsProvider);
      await _whileLoading(ads.preload());
      if (!mounted) return;
      final result = await ads.show(userId: userId, customData: 'chest');
      if (!mounted) return;

      switch (result) {
        case RewardedResult.earned:
          final service = ref.read(walletServiceProvider);
          if (useTestAds) {
            await service.recordTestAdView(purpose: 'chest').catchError((Object e) {
              debugPrint('Test ad view not recorded (set ADMOB_ALLOW_UNVERIFIED_REWARDS=true on the backend): $e');
            });
          }
          if (!mounted) return;
          // The reveal shakes the chest while the backend waits for AdMob's confirmation.
          await revealReward(
            context,
            ref,
            claim: service.openChest,
            box: (lidLift) => TreasureChest(lidLift: lidLift),
          );
        case RewardedResult.skipped:
          _snack('Iklan belum selesai ditonton. Tonton sampai selesai untuk membuka peti.');
        case RewardedResult.unavailable:
          _snack('Iklan belum tersedia. Coba lagi beberapa saat lagi.');
      }
    } finally {
      ref.invalidate(adChestProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T> _whileLoading<T>(Future<T> future) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
    try {
      return await future;
    } finally {
      navigator.pop();
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chest = ref.watch(adChestProvider);
    final status = chest.valueOrNull;

    return Scaffold(
      backgroundColor: _indigo,
      appBar: AppBar(
        title: const Text('Peti Hadiah'),
        backgroundColor: _violet,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_violet, _indigo],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            invalidateWalletFromWidget(ref);
            await ref.refresh(adChestProvider.future).catchError((_) => null);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (status == null)
                Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Center(
                    child: chest.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Peti hadiah sedang tidak tersedia.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                          ),
                  ),
                )
              else ...[
                _header(status),
                const SizedBox(height: 20),
                _grid(status),
                const SizedBox(height: 20),
                _rules(status),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AdChestStatus status) {
    final String subtitle;
    if (status.doneToday) {
      subtitle = 'Semua peti hari ini sudah dibuka. Kembali lagi besok!';
    } else if (status.soldOut) {
      subtitle = 'Hadiah hari ini sudah habis. Kembali lagi besok!';
    } else {
      subtitle = 'Tonton 1 iklan untuk membuka 1 peti dan dapatkan saldo belanja hingga '
          '${formatCurrency(status.maxAmount.toDouble())}.';
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: rewardGold,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            'Sisa ${status.canOpen ? status.remaining : 0} dari ${status.chestsPerDay} peti hari ini',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: rewardBrown),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.95)),
        ),
      ],
    );
  }

  Widget _grid(AdChestStatus status) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < status.chestsPerDay; i++)
              SizedBox(
                width: width,
                child: _ChestTile(
                  number: i + 1,
                  opened: i < status.openedToday,
                  // Only the next chest in line can be opened.
                  next: i == status.openedToday && status.canOpen,
                  busy: _busy,
                  wiggle: _wiggle,
                  onTap: _open,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _rules(AdChestStatus status) {
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: rewardGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.white.withValues(alpha: 0.9))),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cara main', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          line(Icons.play_circle_fill_rounded, 'Ketuk peti, lalu tonton iklan sampai selesai.'),
          line(Icons.account_balance_wallet_rounded, 'Peti langsung terbuka dan saldo belanja masuk ke saldomu.'),
          line(Icons.event_repeat_rounded, '${status.chestsPerDay} peti setiap hari, reset tengah malam WIB.'),
          line(Icons.info_outline_rounded, 'Saldo belanja tidak dapat dicairkan atau ditransfer ke rekening bank.'),
        ],
      ),
    );
  }
}

class _ChestTile extends StatelessWidget {
  const _ChestTile({
    required this.number,
    required this.opened,
    required this.next,
    required this.busy,
    required this.wiggle,
    required this.onTap,
  });

  final int number;
  final bool opened;
  final bool next;
  final bool busy;
  final Animation<double> wiggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = opened ? 'Terbuka' : (next ? (busy ? 'Memuat...' : 'Buka') : 'Terkunci');

    return Material(
      color: Colors.white.withValues(alpha: next ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: next && !busy ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: next ? rewardGold : Colors.white.withValues(alpha: 0.12), width: next ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 64,
                child: Opacity(
                  opacity: next ? 1 : (opened ? 0.45 : 0.7),
                  child: AnimatedBuilder(
                    animation: wiggle,
                    builder: (_, child) => Transform.rotate(
                      angle: next && !busy ? _rattleAngle(wiggle.value, strength: 0.1) : 0,
                      child: child,
                    ),
                    child: FittedBox(child: TreasureChest(lidLift: opened ? 0.3 : 0)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Peti $number',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: next ? rewardGold : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opened ? Icons.check_rounded : (next ? Icons.play_arrow_rounded : Icons.lock_rounded),
                      size: 13,
                      color: next ? rewardBrown : Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: next ? rewardBrown : Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wooden treasure chest with gold bands. [lidLift] 0..1 pops the lid off.
/// Base size is 174 wide, like the bonus gift box, so both fit the reveal.
class TreasureChest extends StatelessWidget {
  const TreasureChest({super.key, this.lidLift = 0});

  final double lidLift;

  @override
  Widget build(BuildContext context) {
    const bodyW = 128.0, bodyH = 78.0, lidW = 138.0, lidH = 44.0, band = 12.0;

    final body = Container(
      width: bodyW,
      height: bodyH,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_wood, _woodDark],
        ),
        border: Border.all(color: rewardGoldDark, width: 4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vertical gold straps
          Positioned(left: 18, top: 0, bottom: 0, child: Container(width: band, color: rewardGoldDark)),
          Positioned(right: 18, top: 0, bottom: 0, child: Container(width: band, color: rewardGoldDark)),
          // Lock plate
          Positioned(
            top: 4,
            child: Container(
              width: 26,
              height: 30,
              decoration: BoxDecoration(
                color: rewardGold,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: rewardGoldDark, width: 2.5),
              ),
              child: const Center(child: Icon(Icons.circle, size: 7, color: _woodDark)),
            ),
          ),
        ],
      ),
    );

    final lid = Container(
      width: lidW,
      height: lidH,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40), bottom: Radius.circular(4)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB45309), _wood],
        ),
        border: Border.all(color: rewardGoldDark, width: 4),
      ),
      child: Stack(
        children: [
          Positioned(left: 19, top: 0, bottom: 0, child: Container(width: band, color: rewardGoldDark)),
          Positioned(right: 19, top: 0, bottom: 0, child: Container(width: band, color: rewardGoldDark)),
        ],
      ),
    );

    return SizedBox(
      width: lidW + 36,
      height: bodyH + lidH + 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Glow from inside once the lid starts to lift
          if (lidLift > 0)
            Positioned(
              bottom: bodyH - 10,
              child: Opacity(
                opacity: (lidLift * 2).clamp(0.0, 1.0),
                child: Container(
                  width: bodyW - 16,
                  height: 20,
                  decoration: BoxDecoration(
                    color: rewardGold,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: rewardGold.withValues(alpha: 0.9), blurRadius: 24, spreadRadius: 6)],
                  ),
                ),
              ),
            ),
          Positioned(bottom: 0, child: body),
          Positioned(
            bottom: bodyH - 6 + lidLift * 110,
            child: Opacity(
              opacity: 1 - (lidLift - 0.6).clamp(0.0, 0.4) / 0.4,
              child: Transform.rotate(angle: -lidLift * 0.6, child: lid),
            ),
          ),
        ],
      ),
    );
  }
}
