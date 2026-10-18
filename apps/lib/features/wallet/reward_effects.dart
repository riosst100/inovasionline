import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

const rewardGold = Color(0xFFFDE047);
const rewardGoldDark = Color(0xFFF59E0B);
const rewardBrown = Color(0xFF713F12);
const _red = Color(0xFFEF4444);

/// Put on the balance figure in the saldo card: collected coins fly there.
final walletBalanceTargetKey = GlobalKey(debugLabel: 'walletBalanceTarget');

/// Flies a gold coin (plus a few trailing ones) from [from] into the saldo
/// card's balance figure. The coin hovers at [from] for [delay] first, e.g.
/// while the app navigates back home. It lives in the root overlay, so it
/// outlives the screen that started it. Completes once the coin has landed
/// (or right away when the saldo card is not on screen).
Future<void> flyCoinToWalletBalance(
  BuildContext context,
  Offset from, {
  Duration delay = Duration.zero,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future.value();
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _CoinFlightHost(
        from: from,
        delay: delay,
        onDone: () {
          entry.remove();
          done.complete();
        },
        onGone: () {
          if (!done.isCompleted) done.complete();
        },
      ),
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _CoinFlightHost extends StatefulWidget {
  const _CoinFlightHost({
    required this.from,
    required this.delay,
    required this.onDone,
    required this.onGone,
  });

  final Offset from;
  final Duration delay;

  /// Landed (or nowhere to land): removes the entry.
  final VoidCallback onDone;

  /// Disposed, e.g. the overlay went away mid-flight.
  final VoidCallback onGone;

  @override
  State<_CoinFlightHost> createState() => _CoinFlightHostState();
}

class _CoinFlightHostState extends State<_CoinFlightHost> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1050));
  Offset? _to;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (widget.delay > Duration.zero) await Future<void>.delayed(widget.delay);
    if (!mounted) return;
    final target = walletBalanceTargetKey.currentContext?.findRenderObject() as RenderBox?;
    if (target != null && target.attached) {
      setState(() {
        _to = target.localToGlobal(Offset(math.min(40, target.size.width / 2), target.size.height / 2));
      });
      try {
        await _controller.forward().orCancel;
      } on TickerCanceled {
        // Overlay went away mid-flight; dispose finishes up.
        return;
      }
    }
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.onGone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final to = _to;
    if (to == null) {
      return Stack(children: [
        Positioned(left: widget.from.dx - 46, top: widget.from.dy - 46, child: const GoldCoin(size: 92)),
      ]);
    }
    return _CoinFlight(animation: _controller, from: widget.from, to: to);
  }
}

/// The collected coin arcing into the balance, shrinking as it goes, with a
/// few smaller coins trailing behind.
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
          colors: [Color(0xFFFEF9C3), rewardGold, rewardGoldDark, Color(0xFFB45309)],
          stops: [0.0, 0.35, 0.8, 1.0],
        ),
        border: Border.all(color: const Color(0xFFFBBF24), width: size * 0.05),
        boxShadow: [
          BoxShadow(color: rewardGoldDark.withValues(alpha: 0.55), blurRadius: size * 0.3, spreadRadius: size * 0.02),
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
            color: rewardBrown,
            shadows: [Shadow(color: Colors.white.withValues(alpha: 0.6), offset: Offset(0, size * 0.015))],
          ),
        ),
      ),
    );
  }
}

/// Gold "saldo belanja" voucher showing [amount].
class RewardTicket extends StatelessWidget {
  const RewardTicket({super.key, required this.amount});

  final num amount;

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
          colors: [Color(0xFFFEF08A), rewardGoldDark],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: rewardGoldDark.withValues(alpha: 0.6), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_rounded, size: 15, color: rewardBrown),
              SizedBox(width: 5),
              Text(
                'SALDO BELANJA',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: rewardBrown, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              formatCurrency(amount.toDouble()),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: rewardBrown),
            ),
          ),
        ],
      ),
    );
  }
}

/// Flips [ticket] around the Y axis into a gold coin as [progress] goes 0..1.
Widget ticketToCoin(double progress, Widget ticket) {
  final m = Curves.easeInOut.transform(progress);
  final coinSide = m >= 0.5;
  final angle = coinSide ? (m - 1) * math.pi : m * math.pi;
  return Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateY(angle),
    child: coinSide ? const SizedBox(width: 170, child: Center(child: GoldCoin(size: 92))) : ticket,
  );
}

/// Rotating gold light rays with a soft glow, centred at 42% of the height.
class RewardRaysPainter extends CustomPainter {
  RewardRaysPainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.75;

    canvas.drawCircle(
      center,
      radius * 0.45,
      Paint()
        ..shader = RadialGradient(colors: [rewardGold.withValues(alpha: 0.55), rewardGold.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: radius * 0.45)),
    );

    final paint = Paint()
      ..shader = RadialGradient(colors: [rewardGold.withValues(alpha: 0.35), rewardGold.withValues(alpha: 0)])
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
  bool shouldRepaint(covariant RewardRaysPainter oldDelegate) => oldDelegate.rotation != rotation;
}

class ConfettiParticle {
  ConfettiParticle(this.angle, this.speed, this.size, this.color, this.spin, this.round);

  static const _colors = [rewardGold, Color(0xFFF472B6), Color(0xFF38BDF8), Color(0xFF4ADE80), Colors.white, _red];

  /// Upward fan of pieces.
  static List<ConfettiParticle> burst(math.Random random, int count) => List.generate(count, (_) {
        return ConfettiParticle(
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

class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.particles, this.progress, {required this.origin});

  final List<ConfettiParticle> particles;
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
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
