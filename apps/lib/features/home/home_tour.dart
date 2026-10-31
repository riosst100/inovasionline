import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/analytics.dart';
import '../../widgets/coach_mark.dart';
import '../shell/main_shell.dart';

/// First-launch tour over home and the bottom bar. It cannot be skipped, and
/// it counts as seen only once the last step is done: if the app is closed
/// halfway, it starts over on the next launch.
class HomeTour {
  HomeTour._();

  /// Bump the suffix to show the tour again to everyone after changing it.
  static const _seenKey = 'home_tour_seen_v1';

  /// Bottom bar tabs, in [MainNavBar] order.
  static const _navTabs = 5;
  static const _postsTab = 0;
  static const _chatTab = 1;
  static const _shopTab = 2;
  static const _ordersTab = 3;
  static const _accountTab = 4;

  /// Set while the tour is on screen.
  static Future<void>? _showing;

  /// Completes once no tour is on screen, so things that would cover it (the
  /// app update check) can wait their turn.
  static Future<void> whenIdle() async {
    await _showing;
  }

  /// Shows the tour if this install has not seen it; true when it was shown.
  static Future<bool> maybeShow(
    BuildContext context, {
    required bool authenticated,
    required ScrollController scroll,
    required GlobalKey wallet,
    required GlobalKey location,
    required GlobalKey cart,
  }) async {
    const storage = FlutterSecureStorage();
    if (await storage.read(key: _seenKey) != null) return false;
    // Another page or dialog is on top: try again next launch.
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return false;

    final steps = [
      CoachStep.key(
        wallet,
        title: 'Saldo Belanja',
        text: authenticated
            ? 'Ini saldo belanja kamu. Saldo ini bisa dipakai untuk membayar belanjaan.'
            : 'Daftar atau masuk dulu di sini, nanti kamu dapat bonus saldo untuk belanja.',
      ),
      CoachStep.key(
        location,
        title: 'Alamat Kirim',
        text: 'Pilih alamat rumah kamu di sini. Barang yang muncul akan disesuaikan '
            'dengan yang tersedia di daerah kamu.',
      ),
      CoachStep.key(
        cart,
        title: 'Keranjang',
        text: 'Barang yang mau kamu beli dikumpulkan di sini. Tekan ini untuk melihat isinya lalu bayar.',
      ),
      _navStep(
        _postsTab,
        title: 'Postingan',
        text: 'Baca pengumuman resmi dan cerita dari warga lain di sini.',
      ),
      _navStep(
        _chatTab,
        title: 'Chat',
        text: 'Kirim pesan ke warga lain, dari satu desa, satu kecamatan, sampai satu kota.',
      ),
      _navStep(
        _ordersTab,
        title: 'Pesanan',
        text: 'Lihat barang yang sedang diantar, juga daftar belanjaan kamu sebelumnya.',
      ),
      _navStep(
        _accountTab,
        title: 'Akun',
        text: 'Atur data diri, alamat, dan pengaturan akun kamu di sini.',
      ),
      _navStep(
        _shopTab,
        title: 'Belanja Online',
        text: 'Tekan tombol ini untuk mulai belanja. Ada banyak promo yang menunggu!',
      ),
    ];

    final showing = _showing = showCoachMarks(
      context,
      steps,
      beforeStep: (index) async {
        // Wallet sits mid-page and the location header at the very top; bring
        // each into view. The rest are pinned (search bar, bottom bar).
        if (index == 0) {
          final walletContext = wallet.currentContext;
          if (walletContext != null && walletContext.mounted) {
            await Scrollable.ensureVisible(
              walletContext,
              alignment: 0.5,
              duration: const Duration(milliseconds: 300),
            );
          }
        } else if (index == 1 && scroll.hasClients && scroll.offset > 0) {
          await scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      },
    );
    try {
      await showing;
    } finally {
      _showing = null;
    }
    await storage.write(key: _seenKey, value: '1');
    Analytics.homeTourCompleted();
    return true;
  }

  /// One tab of the bottom bar; NavigationBar gives every tab an equal share.
  static CoachStep _navStep(int tab, {required String title, required String text}) => CoachStep(
        title: title,
        text: text,
        target: () {
          final bar = CoachStep.rectOf(MainShell.navBarKey);
          if (bar == null) return null;
          final width = bar.width / _navTabs;
          return Rect.fromLTWH(bar.left + width * tab, bar.top, width, bar.height);
        },
      );
}
