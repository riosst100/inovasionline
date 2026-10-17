import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../wallet/wallet_providers.dart';

const _giftRed = Color(0xFFEF4444);
const _giftRedDark = Color(0xFFB91C1C);
const _gold = Color(0xFFFDE047);
const _goldDark = Color(0xFFF59E0B);
const _brown = Color(0xFF713F12);

/// Put on the balance figure in the saldo card: the collected coin flies there.
final walletBalanceTargetKey = GlobalKey(debugLabel: 'walletBalanceTarget');

/// Popped by the gift dialog once the reward has turned into a coin.
class _Collected {
  const _Collected(this.coinCenter);

  final Offset? coinCenter;
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

    final result = await showGeneralDialog<Object?>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Hadiah',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => _GiftDialog(claim: service.claimBonus),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
    );

    if (!mounted) return;

    if (result is _Collected) {
      // Reveal a masked balance so the count-up is visible; the eye icon can hide it again.
      if (ref.read(walletBalanceHiddenProvider)) {
        ref.read(walletBalanceHiddenProvider.notifier).toggle();
      }
      final from = result.coinCenter;
      if (from != null) await _flyCoin(from);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      // Refreshing now makes the saldo card count up to the new balance as the
      // coin lands (and this banner collapse away).
      invalidateWalletFromWidget(ref);
      setState(() => _opening = false);
      return;
    }

    invalidateWalletFromWidget(ref);
    setState(() => _opening = false);

    if (result != null) {
      final message = result is DioException && result.error is ApiException
          ? (result.error as ApiException).message
          : 'Gagal membuka hadiah. Coba lagi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Flies a gold coin (plus a few trailing ones) from [from] into the balance figure.
  Future<void> _flyCoin(Offset from) async {
    final target = walletBalanceTargetKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (target == null || !target.attached || overlay == null) return;
    final to = target.localToGlobal(Offset(math.min(40, target.size.width / 2), target.size.height / 2));

    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1050));
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(child: _CoinFlight(animation: controller, from: from, to: to)),
    );
    overlay.insert(entry);
    try {
      await controller.forward().orCancel;
    } on TickerCanceled {
      // Widget went away mid-flight; nothing to finish.
    } finally {
      entry.remove();
      controller.dispose();
    }
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

/// Full-screen reveal: the box shakes while the claim is in flight, then the
/// lid pops, the reward rises out with confetti and the amount is announced.
/// "Asyik" flips the reward into a gold coin and pops with [_Collected] (its
/// screen position, so the coin can fly on into the balance). Pops with the
/// error if the claim fails.
class _GiftDialog extends StatefulWidget {
  const _GiftDialog({required this.claim});

  final Future<int> Function() claim;

  @override
  State<_GiftDialog> createState() => _GiftDialogState();
}

class _GiftDialogState extends State<_GiftDialog> with TickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..repeat();
  late final _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  late final _rays = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  late final _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  late final _particles = _Particle.burst(math.Random(), 46);
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

  /// Flips around the Y axis: the voucher's front, then the coin's face.
  Widget _ticketOrCoin() {
    final m = Curves.easeInOut.transform(_morph.value);
    final coinSide = m >= 0.5;
    final angle = coinSide ? (m - 1) * math.pi : m * math.pi;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateY(angle),
      child: coinSide
          ? const SizedBox(width: 170, child: Center(child: GoldCoin(size: 92)))
          : _RewardTicket(amount: _amount ?? 0),
    );
  }

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
                            child: CustomPaint(painter: _RaysPainter(rotation: _rays.value * 2 * math.pi)),
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
                              child: KeyedSubtree(key: _coinKey, child: _ticketOrCoin()),
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
                              child: _GiftBox(lidLift: lid.value),
                            ),
                          ),
                          ),
                        ),
                        // Confetti burst from the box mouth
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ConfettiPainter(_particles, confetti.value, origin: const Offset(0.5, 0.62)),
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

/// Shiny gold "Rp" coin.
class GoldCoin extends StatelessWidget {
  const GoldCoin({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFFEF9C3), _gold, _goldDark, Color(0xFFB45309)],
          stops: [0.0, 0.35, 0.8, 1.0],
        ),
        border: Border.all(color: const Color(0xFFFBBF24), width: size * 0.05),
        boxShadow: [
          BoxShadow(color: _goldDark.withValues(alpha: 0.55), blurRadius: size * 0.3, spreadRadius: size * 0.02),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(size * 0.1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.45), width: size * 0.025),
        ),
        alignment: Alignment.center,
        child: Text(
          'Rp',
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w900,
            color: _brown,
            shadows: [Shadow(color: Colors.white.withValues(alpha: 0.6), offset: Offset(0, size * 0.015))],
          ),
        ),
      ),
    );
  }
}

/// The collected coin arcing from the dialog into the balance, shrinking as it
/// goes, with a few smaller coins trailing behind.
class _CoinFlight extends StatelessWidget {
  const _CoinFlight({required this.animation, required this.from, required this.to});

  final Animation<double> animation;
  final Offset from;
  final Offset to;

  static const _trail = 4;
  static const _lag = 0.07;

  Offset _at(double t) {
    final control = Offset(math.max(from.dx, to.dx) + 70, (from.dy + to.dy) / 2 - 30);
    final u = 1 - t;
    return from * (u * u) + control * (2 * u * t) + to * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final coins = <Widget>[];
        // Trailing coins first so the main one is drawn on top.
        for (var i = _trail; i >= 0; i--) {
          final span = 1 - _trail * _lag;
          final raw = ((animation.value - i * _lag) / span).clamp(0.0, 1.0);
          if (i > 0 && (raw <= 0 || raw >= 1)) continue;
          final t = Curves.easeInOutCubic.transform(raw);
          final size = i == 0 ? 92 + (24 - 92) * t : 34 + (16 - 34) * t;
          final p = _at(t);
          coins.add(Positioned(
            left: p.dx - size / 2,
            top: p.dy - size / 2,
            child: Opacity(
              opacity: i == 0 ? (raw > 0.92 ? (1 - raw) / 0.08 : 1.0) : 0.75,
              child: GoldCoin(size: size),
            ),
          ));
        }
        return Stack(children: coins);
      },
    );
  }
}

/// Gold voucher that flies out of the box.
class _RewardTicket extends StatelessWidget {
  const _RewardTicket({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEF08A), _goldDark],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: _goldDark.withValues(alpha: 0.6), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_rounded, size: 15, color: _brown),
              SizedBox(width: 5),
              Text(
                'SALDO BELANJA',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _brown, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatCurrency(amount.toDouble()),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _brown),
            ),
          ),
        ],
      ),
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

class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.75;

    canvas.drawCircle(
      center,
      radius * 0.45,
      Paint()
        ..shader = RadialGradient(colors: [_gold.withValues(alpha: 0.55), _gold.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: radius * 0.45)),
    );

    final paint = Paint()
      ..shader = RadialGradient(colors: [_gold.withValues(alpha: 0.35), _gold.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: center, radius: radius));
    const count = 12;
    for (var i = 0; i < count; i++) {
      final a = rotation + i * 2 * math.pi / count;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + radius * math.cos(a - 0.11), center.dy + radius * math.sin(a - 0.11))
        ..lineTo(center.dx + radius * math.cos(a + 0.11), center.dy + radius * math.sin(a + 0.11))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) => oldDelegate.rotation != rotation;
}

class _Particle {
  _Particle(this.angle, this.speed, this.size, this.color, this.spin, this.round);

  static const _colors = [_gold, Color(0xFFF472B6), Color(0xFF38BDF8), Color(0xFF4ADE80), Colors.white, _giftRed];

  /// Upward fan of pieces.
  static List<_Particle> burst(math.Random random, int count) => List.generate(count, (_) {
        return _Particle(
          -math.pi / 2 + (random.nextDouble() - 0.5) * 2.2,
          180 + random.nextDouble() * 220,
          4 + random.nextDouble() * 5,
          _colors[random.nextInt(_colors.length)],
          (random.nextDouble() - 0.5) * 14,
          random.nextBool(),
        );
      });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.progress, {required this.origin});

  final List<_Particle> particles;
  final double progress;

  /// Fractional position of the burst inside the canvas.
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final start = Offset(size.width * origin.dx, size.height * origin.dy);
    final t = progress * 1.6; // seconds of flight
    const gravity = 420.0;
    final paint = Paint();

    for (final p in particles) {
      final x = start.dx + math.cos(p.angle) * p.speed * t;
      final y = start.dy + math.sin(p.angle) * p.speed * t + 0.5 * gravity * t * t;
      paint.color = p.color.withValues(alpha: (1 - progress).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 1.8), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
