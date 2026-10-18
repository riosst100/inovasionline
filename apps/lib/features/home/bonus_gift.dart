import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../ads/admob.dart';
import '../wallet/reward_effects.dart';
import '../wallet/wallet_providers.dart';

const _giftRed = Color(0xFFEF4444);
const _giftRedDark = Color(0xFFB91C1C);
const _gold = rewardGold;
const _goldDark = rewardGoldDark;
const _brown = rewardBrown;

/// Popped by the gift dialog once the reward has turned into a coin.
class _Collected {
  const _Collected(this.coinCenter);

  final Offset? coinCenter;
}

/// Plays the full-screen reveal for [claim] (the amount credited), with [box]
/// drawing the container whose lid pops ([lidLift] 0..1). Once collected the
/// coin flies into the saldo card and the wallet refreshes; a failed claim
/// shows its message. Also used by the home screen's reward chest.
Future<void> revealReward(
  BuildContext context,
  WidgetRef ref, {
  required Future<int> Function() claim,
  required Widget Function(double lidLift) box,
}) async {
  final result = await showGeneralDialog<Object?>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Hadiah',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => _GiftDialog(claim: claim, box: box),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );

  if (!context.mounted) return;

  if (result is _Collected) {
    // Reveal a masked balance so the count-up is visible; the eye icon can hide it again.
    if (ref.read(walletBalanceHiddenProvider)) {
      ref.read(walletBalanceHiddenProvider.notifier).toggle();
    }
    final from = result.coinCenter;
    if (from != null) await flyCoinToWalletBalance(context, from);
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    // Refreshing now makes the saldo card count up to the new balance as the
    // coin lands (and the bonus banner collapse away).
    invalidateWalletFromWidget(ref);
    return;
  }

  invalidateWalletFromWidget(ref);

  if (result != null) {
    final message = result is DioException && result.error is ApiException
        ? (result.error as ApiException).message
        : 'Gagal membuka hadiah. Coba lagi.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

/// Home banner above the saldo card while the one-time bonus is unclaimed.
/// Tapping it opens the gift box that reveals the (random) amount.
class BonusGiftBanner extends ConsumerStatefulWidget {
  const BonusGiftBanner({super.key});

  @override
  ConsumerState<BonusGiftBanner> createState() => _BonusGiftBannerState();
}

class _BonusGiftBannerState extends ConsumerState<BonusGiftBanner>
    with TickerProviderStateMixin {
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  bool _opening = false;

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final service = ref.read(walletServiceProvider);
    var claim = service.claimBonus;

    if (ref.read(walletProvider).valueOrNull?.bonusRequiresAd ?? false) {
      final watched = await _watchAd();
      if (!mounted) return;
      if (!watched) {
        setState(() => _opening = false);
        return;
      }
      claim = service.claimBonusAfterAd;
    }
    if (!mounted) return;

    await revealReward(
      context,
      ref,
      claim: claim,
      box: (lidLift) => _GiftBox(lidLift: lidLift),
    );
    if (mounted) setState(() => _opening = false);
  }

  /// Explains the deal, then plays the rewarded ad. True once it was watched
  /// to the end; the backend still waits for AdMob's own confirmation.
  Future<bool> _watchAd() async {
    final ads = ref.read(rewardedAdsProvider);
    unawaited(ads.preload());

    final agreed = await showDialog<bool>(
      context: context,
      builder: (_) => const _AdConsentDialog(),
    );
    final userId = ref.read(authProvider).user?.id;
    if (agreed != true || userId == null || !mounted) return false;

    await _whileLoading(ads.preload());
    final result = await ads.show(userId: userId);
    if (!mounted) return false;

    switch (result) {
      case RewardedResult.earned:
        if (useTestAds) {
          await ref.read(walletServiceProvider).recordTestAdView().catchError((Object e) {
            debugPrint('Test ad view not recorded (set ADMOB_ALLOW_UNVERIFIED_REWARDS=true on the backend): $e');
          });
        }
        return true;
      case RewardedResult.skipped:
        _snack('Iklan belum selesai ditonton. Tonton sampai selesai untuk mendapatkan bonus saldo.');
      case RewardedResult.unavailable:
        _snack('Iklan belum tersedia. Coba lagi beberapa saat lagi.');
    }
    return false;
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
    final authenticated = ref.watch(
      authProvider.select((s) => s.status == AuthStatus.authenticated),
    );
    final summary = ref.watch(walletProvider).valueOrNull;
    final visible = authenticated && summary != null && summary.bonusAvailable;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: visible ? _banner(summary.bonusMax) : const SizedBox(width: double.infinity),
    );
  }

  Widget _banner(int bonusMax) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF97316), Color(0xFFEC4899)],
                ),
              ),
              child: InkWell(
                onTap: _open,
                child: Stack(
                  children: [
                    Positioned(right: 60, top: -18, child: _sparkle(46, 0.12)),
                    Positioned(right: -14, bottom: -24, child: _sparkle(70, 0.10)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _wiggle,
                            builder: (_, child) {
                              // A quick wiggle at the start of every cycle, then rest.
                              final t = _wiggle.value;
                              final angle = t < 0.25 ? math.sin(t * 4 * math.pi * 4) * 0.14 * (1 - t * 4) : 0.0;
                              return Transform.rotate(angle: angle, child: child);
                            },
                            child: const SizedBox(width: 50, height: 50, child: _GiftBox(scale: 0.42)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Hadiah Saldo Belanja',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text.rich(
                                  TextSpan(
                                    text: 'Buka kadonya & dapatkan hingga ',
                                    children: [
                                      TextSpan(
                                        text: formatCurrency(bonusMax.toDouble()),
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: _gold),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.95),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: _brown.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _opening
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _brown),
                                  )
                                : const Text(
                                    'Klaim',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _brown),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sparkle(double size, double alpha) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha),
          ),
        ),
      );
}

/// Shown on "Klaim" while admin requires an ad: the bonus is paid for a rewarded
/// ad watched to the end. Pops true when the user agrees to watch.
class _AdConsentDialog extends StatelessWidget {
  const _AdConsentDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_giftRed, _giftRedDark]),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tonton Iklan untuk Bonus',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Untuk mendapatkan bonus saldo, kamu perlu menonton iklan sampai selesai. '
              'Bonus saldo langsung masuk setelah iklan selesai.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: _giftRed,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Tonton Iklan', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Nanti Saja'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen reveal: the box shakes while the claim is in flight, then the
/// lid pops, the reward rises out with confetti and the amount is announced.
/// "Asyik" flips the reward into a gold coin and pops with [_Collected] (its
/// screen position, so the coin can fly on into the balance). Pops with the
/// error if the claim fails.
class _GiftDialog extends StatefulWidget {
  const _GiftDialog({required this.claim, required this.box});

  final Future<int> Function() claim;
  final Widget Function(double lidLift) box;

  @override
  State<_GiftDialog> createState() => _GiftDialogState();
}

class _GiftDialogState extends State<_GiftDialog> with TickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..repeat();
  late final _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  late final _rays = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  late final _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  late final _particles = ConfettiParticle.burst(math.Random(), 46);
  final _coinKey = GlobalKey();

  int? _amount;
  bool _collecting = false;

  Future<void> _collect() async {
    if (_collecting) return;
    setState(() => _collecting = true);
    HapticFeedback.selectionClick();
    await _morph.forward();
    if (!mounted) return;
    final box = _coinKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null && box.attached ? box.localToGlobal(box.size.center(Offset.zero)) : null;
    Navigator.of(context).pop(_Collected(center));
  }

  @override
  void initState() {
    super.initState();
    _claim();
  }

  Future<void> _claim() async {
    try {
      // Let the shake play for a moment even when the API is fast.
      final results = await Future.wait<Object>([
        widget.claim(),
        Future<Object>.delayed(const Duration(milliseconds: 1300), () => 0),
      ]);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _shake.stop();
      setState(() => _amount = results.first as int);
      _open.forward();
    } catch (e) {
      if (mounted) Navigator.of(context).pop(e);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _open.dispose();
    _rays.dispose();
    _morph.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(parent: _open, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final lid = _interval(0.0, 0.32, Curves.easeOutCubic);
    final pop = _interval(0.0, 0.18);
    final reward = _interval(0.14, 0.58, Curves.easeOutBack);
    final glow = _interval(0.18, 0.55);
    final confetti = _interval(0.14, 1.0, Curves.linear);
    final text = _interval(0.52, 0.86, Curves.easeOutCubic);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: 320,
          child: AnimatedBuilder(
            animation: Listenable.merge([_shake, _open, _rays, _morph]),
            builder: (context, _) {
              final shaking = _amount == null;
              final shakeAngle = shaking ? math.sin(_shake.value * 2 * math.pi) * 0.09 : 0.0;
              final boxScale = 1 + math.sin(pop.value * math.pi) * 0.12;
              // Everything but the reward fades out while it turns into a coin.
              final rest = 1 - Curves.easeOut.transform((_morph.value * 2).clamp(0.0, 1.0));

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 300,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Light rays behind the reward
                        Positioned.fill(
                          child: Opacity(
                            opacity: glow.value * (0.4 + 0.6 * rest),
                            child: CustomPaint(painter: RewardRaysPainter(rotation: _rays.value * 2 * math.pi)),
                          ),
                        ),
                        // Reward rising out of the box; it settles centred on the rays
                        // (ticket ~70 tall, so bottom 140 puts its centre at the rays' y).
                        Positioned(
                          bottom: 70 + reward.value * 70,
                          child: Opacity(
                            opacity: reward.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.3 + reward.value * 0.7,
                              child: KeyedSubtree(
                                key: _coinKey,
                                child: ticketToCoin(_morph.value, RewardTicket(amount: _amount ?? 0)),
                              ),
                            ),
                          ),
                        ),
                        // Box (body + lid), shaking while we wait
                        Positioned(
                          bottom: 16,
                          child: Opacity(
                            opacity: rest,
                            child: Transform.rotate(
                            angle: shakeAngle,
                            alignment: Alignment.bottomCenter,
                            child: Transform.scale(
                              scale: boxScale,
                              alignment: Alignment.bottomCenter,
                              child: widget.box(lid.value),
                            ),
                          ),
                          ),
                        ),
                        // Confetti burst from the box mouth
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: ConfettiPainter(_particles, confetti.value, origin: const Offset(0.5, 0.62)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (shaking)
                    const Text(
                      'Membuka hadiahmu...',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    )
                  else
                    Opacity(
                      opacity: text.value * rest,
                      child: Transform.translate(
                        offset: Offset(0, (1 - text.value) * 24),
                        child: _Congrats(
                          amount: _amount!,
                          onDone: text.value > 0.9 && !_collecting ? _collect : null,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Congrats extends StatelessWidget {
  const _Congrats({required this.amount, required this.onDone});

  final int amount;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Selamat! 🎉',
          style: TextStyle(color: _gold, fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kamu mendapatkan saldo belanja',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrency(amount.toDouble()),
          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          'Saldo sudah masuk dan siap dipakai belanja.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 220,
          height: 46,
          child: FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _brown,
              disabledBackgroundColor: _gold,
              disabledForegroundColor: _brown,
              shape: const StadiumBorder(),
            ),
            child: const Text('Asyik, belanja sekarang!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}


/// A red gift box with a gold ribbon. [lidLift] 0..1 pops the lid off.
/// [scale] shrinks it for the banner (base size is 140 wide).
class _GiftBox extends StatelessWidget {
  const _GiftBox({this.lidLift = 0, this.scale = 1});

  final double lidLift;
  final double scale;

  @override
  Widget build(BuildContext context) {
    const bodyW = 116.0, bodyH = 88.0, lidW = 134.0, lidH = 30.0, ribbon = 20.0;

    final body = Container(
      width: bodyW,
      height: bodyH,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_giftRed, _giftRedDark],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: Center(child: Container(width: ribbon, color: _gold)),
    );

    final lid = SizedBox(
      width: lidW,
      height: lidH + 26,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Bow loops
          Positioned(top: 0, left: lidW / 2 - 34, child: _bowLoop(-0.5)),
          Positioned(top: 0, right: lidW / 2 - 34, child: _bowLoop(0.5)),
          Container(
            width: lidW,
            height: lidH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF87171), _giftRed],
              ),
            ),
            child: Center(child: Container(width: ribbon, color: _gold)),
          ),
          Positioned(
            bottom: lidH - 8,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(color: _goldDark, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );

    final box = SizedBox(
      width: lidW + 40,
      height: bodyH + lidH + 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(bottom: 0, child: body),
          Positioned(
            bottom: bodyH - 4 + lidLift * 110,
            child: Opacity(
              opacity: (1 - (lidLift - 0.6).clamp(0.0, 0.4) / 0.4),
              child: Transform.rotate(angle: -lidLift * 0.6, child: lid),
            ),
          ),
        ],
      ),
    );

    if (scale == 1) return box;
    return FittedBox(child: box);
  }

  static Widget _bowLoop(double angle) => Transform.rotate(
        angle: angle,
        child: Container(
          width: 34,
          height: 28,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _goldDark, width: 3),
          ),
        ),
      );
}

