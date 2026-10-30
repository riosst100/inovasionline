import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../wallet/reward_effects.dart';

/// One-off welcome shown as the user steps into the app: confetti from both
/// bottom corners and a greeting that pops in and fades out on its own. Ignores
/// touches, so the app underneath stays usable throughout.
class WelcomeBurst extends StatefulWidget {
  const WelcomeBurst({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WelcomeBurst> createState() => _WelcomeBurstState();
}

class _WelcomeBurstState extends State<WelcomeBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward().whenComplete(widget.onDone);

  final _random = math.Random();
  late final _left = ConfettiParticle.burst(_random, 38);
  late final _right = ConfettiParticle.burst(_random, 38);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // Greeting: pops in over the first 18%, holds, fades out after 75%.
            final pop = Curves.easeOutBack.transform(
              (t / 0.18).clamp(0.0, 1.0),
            );
            final fade = t < 0.75
                ? 1.0
                : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
            // Confetti plays through the first two thirds.
            final burst = (t / 0.65).clamp(0.0, 1.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Soft dim so the white greeting reads over any page.
                ColoredBox(color: Colors.black.withValues(alpha: 0.4 * fade)),
                CustomPaint(
                  painter: ConfettiPainter(
                    _left,
                    burst,
                    origin: const Offset(0.08, 1.0),
                  ),
                ),
                CustomPaint(
                  painter: ConfettiPainter(
                    _right,
                    burst,
                    origin: const Offset(0.92, 1.0),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.35),
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * pop,
                      child: const _WelcomeText(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The greeting itself: bare text over the scrim, no card.
class _WelcomeText extends StatelessWidget {
  const _WelcomeText();

  static const _shadow = [
    Shadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: TextStyle(fontSize: 54, shadows: _shadow)),
            SizedBox(height: 8),
            Text(
              'Selamat Datang!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: _shadow,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Selamat berbelanja di Inovasi Online',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: _shadow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
