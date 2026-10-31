import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// One stop of a [showCoachMarks] tour: the widget under [target] is lit up
/// and [text] explains it.
class CoachStep {
  const CoachStep({required this.target, required this.title, required this.text});

  /// Global rect of what to highlight; null when it is not on screen (the
  /// step is then skipped).
  final Rect? Function() target;
  final String title;
  final String text;

  /// Highlights the widget that carries [key], scrolling it into view first.
  factory CoachStep.key(GlobalKey key, {required String title, required String text}) =>
      CoachStep(target: () => rectOf(key), title: title, text: text);

  static Rect? rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Dims the screen except one spot at a time, with a card explaining it.
/// Tapping anywhere goes to the next step. It cannot be skipped or closed with
/// the back button; it completes after the last step.
Future<void> showCoachMarks(
  BuildContext context,
  List<CoachStep> steps, {
  Future<void> Function(int index)? beforeStep,
}) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => PopScope(
      canPop: false,
      child: _CoachMarkOverlay(steps: steps, beforeStep: beforeStep),
    ),
    transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

class _CoachMarkOverlay extends StatefulWidget {
  const _CoachMarkOverlay({required this.steps, this.beforeStep});

  final List<CoachStep> steps;
  final Future<void> Function(int index)? beforeStep;

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay> {
  static const _padding = 6.0;

  int _index = -1;
  Rect? _rect;
  bool _moving = false;

  /// The page underneath can still shift (images, data arriving), so the spot
  /// is re-measured a few times a second.
  Timer? _follow;

  @override
  void initState() {
    super.initState();
    _goTo(0);
    _follow = Timer.periodic(const Duration(milliseconds: 250), (_) => _measure());
  }

  @override
  void dispose() {
    _follow?.cancel();
    super.dispose();
  }

  Future<void> _goTo(int index) async {
    if (_moving) return;
    _moving = true;
    try {
      for (var i = index; i < widget.steps.length; i++) {
        await widget.beforeStep?.call(i);
        if (!mounted) return;
        final rect = _globalToLocal(widget.steps[i].target());
        if (rect == null) continue;
        setState(() {
          _index = i;
          _rect = rect;
        });
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      _moving = false;
    }
  }

  void _measure() {
    if (_index < 0 || _moving || !mounted) return;
    final rect = _globalToLocal(widget.steps[_index].target());
    if (rect != null && rect != _rect) setState(() => _rect = rect);
  }

  Rect? _globalToLocal(Rect? rect) {
    final box = context.findRenderObject() as RenderBox?;
    if (rect == null || box == null || !box.hasSize) return rect;
    return box.globalToLocal(rect.topLeft) & rect.size;
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    if (rect == null) return const SizedBox.expand();

    final step = widget.steps[_index];
    final spot = rect.inflate(_padding);
    final screen = MediaQuery.sizeOf(context);
    // The card goes on the side of the spot that has more room.
    final below = spot.center.dy < screen.height / 2;
    final isLast = _index == widget.steps.length - 1;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goTo(_index + 1),
        child: Stack(
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: spot),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(painter: _SpotPainter(value ?? spot)),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              top: below ? spot.bottom + 12 : null,
              bottom: below ? null : screen.height - spot.top + 12,
              child: _CoachCard(
                title: step.title,
                text: step.text,
                stepLabel: '${_index + 1} dari ${widget.steps.length}',
                nextLabel: isLast ? 'Mulai' : 'Lanjut',
                onNext: () => _goTo(_index + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.title,
    required this.text,
    required this.stepLabel,
    required this.nextLabel,
    required this.onNext,
  });

  final String title;
  final String text;
  final String stepLabel;
  final String nextLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.foreground),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(stepLabel, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(nextLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dark layer over the whole screen with a rounded hole at [spot].
class _SpotPainter extends CustomPainter {
  const _SpotPainter(this.spot);

  final Rect spot;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(spot, const Radius.circular(12));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotPainter oldDelegate) => oldDelegate.spot != spot;
}
