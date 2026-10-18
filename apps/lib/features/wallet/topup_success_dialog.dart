import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import 'reward_effects.dart';

/// Celebrates a paid top-up the way the new-user gift does, minus the box: the
/// saldo voucher pops in over spinning rays with confetti. The action button
/// flips the voucher into a gold coin and returns the coin's screen position
/// (null if it could not be measured), so it can fly on into the balance.
Future<Offset?> showTopupSuccessDialog(
  BuildContext context, {
  required double amount,
  required String actionLabel,
}) {
  return showGeneralDialog<Offset?>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Top up berhasil',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => _TopupSuccessDialog(amount: amount, actionLabel: actionLabel),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
  );
}

class _TopupSuccessDialog extends StatefulWidget {
  const _TopupSuccessDialog({required this.amount, required this.actionLabel});

  final double amount;
  final String actionLabel;

  @override
  State<_TopupSuccessDialog> createState() => _TopupSuccessDialogState();
}

class _TopupSuccessDialogState extends State<_TopupSuccessDialog> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  late final _rays = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  late final _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  late final _particles = ConfettiParticle.burst(math.Random(), 46);
  final _coinKey = GlobalKey();

  bool _collecting = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _intro.dispose();
    _rays.dispose();
    _morph.dispose();
    super.dispose();
  }

  Future<void> _collect() async {
    if (_collecting) return;
    setState(() => _collecting = true);
    HapticFeedback.selectionClick();
    await _morph.forward();
    if (!mounted) return;
    final box = _coinKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null && box.attached ? box.localToGlobal(box.size.center(Offset.zero)) : null;
    Navigator.of(context).pop(center);
  }

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final reward = _interval(0.0, 0.4, Curves.easeOutBack);
    final glow = _interval(0.05, 0.4);
    final confetti = _interval(0.08, 1.0, Curves.linear);
    final text = _interval(0.35, 0.75, Curves.easeOutCubic);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: 320,
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _rays, _morph]),
            builder: (context, _) {
              // Everything but the voucher fades out while it turns into a coin.
              final rest = 1 - Curves.easeOut.transform((_morph.value * 2).clamp(0.0, 1.0));

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 240,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Opacity(
                            opacity: glow.value.clamp(0.0, 1.0) * (0.4 + 0.6 * rest),
                            child: CustomPaint(painter: RewardRaysPainter(rotation: _rays.value * 2 * math.pi)),
                          ),
                        ),
                        // Centred on the rays (42% down).
                        Align(
                          alignment: const Alignment(0, -0.16),
                          child: Opacity(
                            opacity: reward.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.3 + reward.value * 0.7,
                              child: KeyedSubtree(
                                key: _coinKey,
                                child: ticketToCoin(_morph.value, RewardTicket(amount: widget.amount)),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: ConfettiPainter(_particles, confetti.value, origin: const Offset(0.5, 0.42)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: text.value * rest,
                    child: Transform.translate(
                      offset: Offset(0, (1 - text.value) * 24),
                      child: _Message(
                        amount: widget.amount,
                        actionLabel: widget.actionLabel,
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

class _Message extends StatelessWidget {
  const _Message({required this.amount, required this.actionLabel, required this.onDone});

  final double amount;
  final String actionLabel;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Top Up Berhasil! 🎉',
          style: TextStyle(color: rewardGold, fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Saldo belanjamu bertambah',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrency(amount),
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
              backgroundColor: rewardGold,
              foregroundColor: rewardBrown,
              disabledBackgroundColor: rewardGold,
              disabledForegroundColor: rewardBrown,
              shape: const StadiumBorder(),
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}
