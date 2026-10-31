import 'package:flutter/widgets.dart';

/// Runs [loopController] on repeat, but stops it when the system
/// "remove animations" accessibility setting is on.
///
/// By default the controller runs the whole time. Animations that move only at the start of each
/// cycle and then rest (a rattle, a shine) set [loopActiveFraction] to the part that moves: the
/// controller then runs just that part and stays completely idle for the rest of the cycle,
/// instead of ticking 60 times a second while nothing changes.
mixin ReduceMotionLoop<T extends StatefulWidget> on State<T> {
  AnimationController get loopController;

  /// Fraction (0..1] of each cycle that moves; 1 keeps the controller running continuously.
  double get loopActiveFraction => 1.0;

  bool _loopRunning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loopRunning = false;
      loopController.stop();
    } else if (!_loopRunning) {
      _loopRunning = true;
      _runLoop();
    }
  }

  @override
  void dispose() {
    _loopRunning = false;
    super.dispose();
  }

  Future<void> _runLoop() async {
    final controller = loopController;
    final fraction = loopActiveFraction;
    if (fraction >= 1) {
      controller.repeat();
      return;
    }

    final cycle = controller.duration!;
    final active = cycle * fraction;
    while (mounted && _loopRunning) {
      await controller.animateTo(fraction, duration: active);
      if (!mounted || !_loopRunning) return;
      await Future<void>.delayed(cycle - active);
      if (!mounted || !_loopRunning) return;
      controller.value = 0;
    }
  }
}
