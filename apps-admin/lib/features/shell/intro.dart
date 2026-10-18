import 'dart:async';

import 'package:flutter/material.dart';

/// The dot of the logo's "i".
const _logoOrange = Color(0xFFFB7A2E);

/// Same color as the native splash (pubspec.yaml `flutter_native_splash`).
const splashColor = Color(0xFF2A3436);

/// Just the logo out of the native splash image (logo_splash.png is a 1152px
/// canvas read as 4x, i.e. 288dp, by flutter_native_splash, with the logo
/// 64dp in the middle); small so it decodes quickly.
const _splashLogo = AssetImage('assets/images/logo_splash_mark.png');
const _splashLogoSize = 64.0;

/// Loads the splash logo into the image cache before [runApp], so the first
/// Flutter frame already shows it and swapping out the native splash (which
/// happens on that frame) does not flash an empty screen.
Future<void> precacheSplashLogo() {
  final done = Completer<void>();
  final stream = _splashLogo.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
    onError: (_, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
  );
  stream.addListener(listener);
  return done.future;
}

/// Plays the splash intro over [child], then fades it out. Mirrors the
/// customer app (apps/lib/features/shell/permission_gate.dart).
class IntroGate extends StatefulWidget {
  const IntroGate({super.key, required this.child});

  final Widget child;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool _played = false;
  bool _gone = false;

  @override
  Widget build(BuildContext context) {
    // Always a Stack so the intro fading out never remounts what is beneath.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_gone)
          IgnorePointer(
            ignoring: _played,
            child: AnimatedOpacity(
              opacity: _played ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              onEnd: () {
                if (_played) setState(() => _gone = true);
              },
              child: _SplashIntro(onPlayed: () => setState(() => _played = true)),
            ),
          ),
      ],
    );
  }
}

/// Picks up where the native splash (which cannot animate) leaves off: its
/// first frame is pixel-identical to the splash, then the logo slides left
/// while "Inovasi Online" and the "Admin" badge unroll out from behind it.
class _SplashIntro extends StatefulWidget {
  const _SplashIntro({required this.onPlayed});

  final VoidCallback onPlayed;

  @override
  State<_SplashIntro> createState() => _SplashIntroState();
}

class _SplashIntroState extends State<_SplashIntro> with SingleTickerProviderStateMixin {
  static const _gap = 8.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _reveal = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _play();
  }

  Future<void> _play() async {
    // The first frames are slow (engine warm-up, native splash going away);
    // starting before they are out would skip the start of the animation.
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    // A beat on the splash-identical frame so the hand-off is seamless.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) widget.onPlayed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: splashColor,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The Row grows as the wordmark unrolls; Center keeps it
              // centred, which is what slides the logo to the left.
              const RepaintBoundary(
                child: Image(
                  image: _splashLogo,
                  width: _splashLogoSize,
                  height: _splashLogoSize,
                  gaplessPlayback: true,
                ),
              ),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _reveal.value,
                  child: Padding(
                    padding: const EdgeInsets.only(left: _gap),
                    child: Transform.translate(
                      offset: Offset(-24 * (1 - _reveal.value), 0),
                      child: Opacity(opacity: _fade.value, child: const _Wordmark()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    // Shorter than the 64dp logo, so the Row's height never changes.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INOVASI ONLINE',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: _logoOrange, borderRadius: BorderRadius.circular(20)),
          child: const Text(
            'ADMIN',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}
