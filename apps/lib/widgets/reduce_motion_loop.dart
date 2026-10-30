import 'package:flutter/widgets.dart';

/// Runs [loopController] on repeat, but stops it when the system
/// "remove animations" accessibility setting is on.
mixin ReduceMotionLoop<T extends StatefulWidget> on State<T> {
  AnimationController get loopController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      loopController.stop();
    } else if (!loopController.isAnimating) {
      loopController.repeat();
    }
  }
}
