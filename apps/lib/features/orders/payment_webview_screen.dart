import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/wallet.dart';
import '../../providers/core_providers.dart';
import '../wallet/wallet_providers.dart';
import 'order_providers.dart';

/// Midtrans Snap page for an order payment or a balance top-up (exactly one of
/// [orderId] / [topupId]). Pops with the refreshed top-up for top-ups.
class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({super.key, required String this.orderId, required this.redirectUrl}) : topupId = null;

  const PaymentWebViewScreen.topup({super.key, required String this.topupId, required this.redirectUrl})
      : orderId = null;

  final String? orderId;
  final String? topupId;
  final String redirectUrl;

  @override
  ConsumerState<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;

            // Midtrans appends status_code/transaction_status to the finish/unfinish/error redirect.
            if (uri.queryParameters.containsKey('transaction_status')) {
              _close();
              return NavigationDecision.prevent;
            }

            // E-wallet deeplinks (gojek://, shopeeid://, intent://...) must open the wallet app.
            if (uri.scheme != 'http' && uri.scheme != 'https') {
              _openExternal(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(_snapUrl(widget.redirectUrl));
  }

  /// Snap redirect mode takes its options as query parameters; force the Indonesian UI.
  static Uri _snapUrl(String redirectUrl) {
    final uri = Uri.parse(redirectUrl);
    return uri.replace(queryParameters: {...uri.queryParameters, 'language': 'id'});
  }

  Future<void> _openExternal(Uri uri) async {
    final target = uri.scheme == 'intent' ? _parseAndroidIntent(uri) : uri;
    final opened = target != null && await launchUrl(target, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aplikasi pembayaran tidak ditemukan. Pilih metode lain atau scan QR.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Turns `intent://path#Intent;scheme=gojek;...;end` into `gojek://path`.
  Uri? _parseAndroidIntent(Uri uri) {
    final raw = uri.toString();
    final hashIndex = raw.indexOf('#Intent;');
    if (hashIndex < 0) return null;
    final params = <String, String>{};
    for (final part in raw.substring(hashIndex + 8).split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) params[part.substring(0, eq)] = part.substring(eq + 1);
    }
    final fallback = params['S.browser_fallback_url'];
    final scheme = params['scheme'];
    if (scheme == null) return fallback != null ? Uri.tryParse(Uri.decodeComponent(fallback)) : null;
    return Uri.tryParse('$scheme://${raw.substring('intent://'.length, hashIndex)}');
  }

  /// Syncs the payment status with Midtrans before leaving, so the order screen is current
  /// even when the notification webhook has not arrived yet.
  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);

    final topupId = widget.topupId;
    if (topupId != null) {
      WalletTopup? topup;
      try {
        topup = await ref.read(walletServiceProvider).topupStatus(topupId);
      } catch (_) {
        // The webhook still credits the balance; the wallet screen refreshes on resume.
      }
      invalidateWalletFromWidget(ref);
      if (!mounted) return;
      context.canPop() ? context.pop(topup) : context.go('/wallet');
      return;
    }

    final orderId = widget.orderId!;
    try {
      await ref.read(checkoutServiceProvider).paymentStatus(orderId);
    } catch (_) {
      // The webhook still updates the order; the detail screen just shows the older state.
    }
    ref.invalidate(orderDetailProvider(orderId));
    ref.invalidate(myOrdersProvider);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders/$orderId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading || _closing) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
