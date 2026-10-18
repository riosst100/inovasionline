import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/wallet.dart';
import '../../providers/core_providers.dart';
import 'reward_effects.dart';
import 'topup_success_dialog.dart';
import 'wallet_providers.dart';

/// Route `extra` for a top-up opened from checkout: success goes back there
/// instead of home.
const topupFromCheckout = 'checkout';

/// Picks an amount, creates a Midtrans top-up and opens its payment page.
class TopupScreen extends ConsumerStatefulWidget {
  const TopupScreen({super.key, this.fromCheckout = false});

  final bool fromCheckout;

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  static const _presets = [20000, 50000, 100000, 200000, 500000, 1000000];

  final _controller = TextEditingController();
  var _submitting = false;

  int get _amount => int.tryParse(_controller.text.replaceAll('.', '')) ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setAmount(int value) {
    final text = formatCurrency(value).replaceFirst('Rp', '').trim();
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  String? _validate(WalletSummary wallet) {
    final amount = _amount;
    if (amount == 0) return null;
    if (amount < wallet.topupMin) {
      return 'Minimal top up ${formatCurrency(wallet.topupMin)}';
    }
    if (amount > wallet.topupMax) {
      return 'Maksimal top up ${formatCurrency(wallet.topupMax)}';
    }
    if (amount > wallet.topupRoom) {
      return 'Saldo maksimal ${formatCurrency(wallet.maxBalance)}. Kamu bisa top up hingga ${formatCurrency(wallet.topupRoom)}.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final WalletTopup topup;
    final String url;
    try {
      topup = await ref.read(walletServiceProvider).createTopup(_amount);
      url = topup.paymentRedirectUrl ?? (throw Exception('Link pembayaran tidak tersedia.'));
    } catch (e, st) {
      debugPrint('createTopup failed: $e\n$st');
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e is DioException && e.error is ApiException
          ? (e.error as ApiException).message
          : 'Gagal membuat top up. Coba lagi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!mounted) return;

    // Keep the home card on the old balance (the payment page refreshes the
    // wallet) until the coin lands there.
    final hold = ref.read(walletBalanceHoldProvider.notifier);
    hold.state = ref.read(walletProvider).valueOrNull?.balance;
    var landing = false;
    try {
      final result = await context.push<WalletTopup?>(
        '/wallet/topups/${topup.id}/pay',
        extra: url,
      );
      if (!mounted) return;

      if (result?.isPaid == true) {
        landing = await _celebrate(result!, hold);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Top up belum dibayar. Saldo masuk otomatis setelah pembayaran selesai.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (!landing) hold.state = null;
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Success dialog, then home with the coin flight (or back to checkout).
  /// Returns whether the flight took over clearing [hold]. A glitch here must
  /// not read as a failed top-up: the money is in, so fall back to a snackbar.
  Future<bool> _celebrate(WalletTopup result, StateController<double?> hold) async {
    try {
      final coin = await showTopupSuccessDialog(
        context,
        amount: result.amount,
        actionLabel: widget.fromCheckout ? 'Lanjut Bayar' : 'Lanjut Belanja',
      );
      if (!mounted) return false;
      if (widget.fromCheckout || coin == null) {
        context.pop();
        return false;
      }
      _landOnHome(coin, hold);
      return true;
    } catch (e, st) {
      debugPrint('Top-up success animation failed: $e\n$st');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Top up ${formatCurrency(result.amount)} berhasil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
      return false;
    }
  }

  /// Goes home and flies the coin into the saldo card, then lets the balance
  /// count up. Runs on after this screen is gone, so it only touches [hold].
  void _landOnHome(Offset coin, StateController<double?> hold) {
    // Reveal a masked balance so the count-up is visible; the eye icon can hide it again.
    if (ref.read(walletBalanceHiddenProvider)) {
      ref.read(walletBalanceHiddenProvider.notifier).toggle();
    }
    // The coin hovers while the pushed screens pop off the home screen.
    final flight = flyCoinToWalletBalance(context, coin, delay: const Duration(milliseconds: 450));
    context.go('/');
    flight.whenComplete(() {
      HapticFeedback.lightImpact();
      hold.state = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final error = wallet == null ? null : _validate(wallet);
    final canSubmit =
        wallet != null && _amount > 0 && error == null && !_submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Top Up Saldo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Saldo saat ini: ${wallet == null ? '—' : formatCurrency(wallet.balance)}',
            style: const TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _ThousandsFormatter(),
            ],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
              hintText: '0',
              errorText: error,
              errorMaxLines: 2,
              helperText: wallet == null
                  ? null
                  : 'Min ${formatCurrency(wallet.topupMin)} · Maks ${formatCurrency(wallet.topupRoom)}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  label: Text(formatCurrency(preset)),
                  selected: _amount == preset,
                  onSelected: wallet != null && preset <= wallet.topupRoom
                      ? (_) => _setAmount(preset)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _amount > 0
                        ? 'Top Up ${formatCurrency(_amount)}'
                        : 'Top Up',
                  ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pembayaran top up lewat Midtrans (QRIS, e-wallet, virtual account, kartu). '
            'Saldo masuk otomatis setelah pembayaran berhasil.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats digits as 1.000.000 while typing.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return const TextEditingValue();
    final value = int.tryParse(digits);
    if (value == null) return oldValue;
    final text = formatCurrency(value).replaceFirst('Rp', '').trim();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
