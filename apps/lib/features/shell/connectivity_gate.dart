import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../core/api/connectivity.dart';

/// Keeps [Connectivity] up to date and floats a pill under the top bar: red
/// "Tidak ada koneksi internet." that stays until the connection is back, then
/// green "Koneksi kembali." for a moment.
/// The app stays usable: screens with data already loaded still work, and
/// [ApiClient] refuses anything that has to be sent to the server
/// (POST/PUT/PATCH/DELETE). Checked at start, on resume, and every few seconds
/// while offline.
class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate>
    with WidgetsBindingObserver {
  static const _retryEvery = Duration(seconds: 4);
  static const _restoredFor = Duration(seconds: 2);

  Timer? _retryTimer;
  Timer? _hideTimer;
  bool _popupVisible = false;

  /// Showing the green "connected again" state instead of the red one.
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Connectivity.online.addListener(_onOnlineChanged);
    Connectivity.check();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _hideTimer?.cancel();
    Connectivity.online.removeListener(_onOnlineChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Connectivity.check();
  }

  void _onOnlineChanged() {
    _retryTimer?.cancel();
    _hideTimer?.cancel();
    if (!mounted) return;

    if (Connectivity.online.value) {
      // Only celebrate if the red popup was actually showing.
      if (!_popupVisible) return;
      setState(() => _restored = true);
      _hideTimer = Timer(_restoredFor, () {
        if (mounted) {
          setState(() => _popupVisible = false);
        }
      });
    } else {
      setState(() {
        _restored = false;
        _popupVisible = true;
      });
      _retryTimer = Timer.periodic(_retryEvery, (_) => Connectivity.check());
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _restored
        ? Colors.green.shade600.withValues(alpha: 0.7)
        : AppColors.destructive.withValues(alpha: 0.7);
    // Sits just under the top bar (status bar + toolbar), floating over the content.
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: top,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _popupVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _restored ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _restored ? 'Koneksi kembali.' : 'Tidak ada koneksi internet.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          // This sits above the Navigator, so no Material supplies a text style:
                          // without this Flutter draws its yellow debug underline.
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
