import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/wallet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

/// Null while signed out. Invalidate after anything that moves money
/// (checkout with balance, cancelling a paid order, a top-up).
final walletProvider = FutureProvider<WalletSummary?>((ref) async {
  final authenticated = ref.watch(
    authProvider.select((s) => s.status == AuthStatus.authenticated),
  );
  if (!authenticated) return null;
  return ref.watch(walletServiceProvider).summary();
});

final walletTransactionsProvider =
    FutureProvider.autoDispose<List<WalletTransaction>>((ref) {
      return ref.watch(walletServiceProvider).transactions();
    });

/// Refreshes every balance view at once.
void invalidateWallet(Ref ref) {
  ref.invalidate(walletProvider);
  ref.invalidate(walletTransactionsProvider);
}

void invalidateWalletFromWidget(WidgetRef ref) {
  ref.invalidate(walletProvider);
  ref.invalidate(walletTransactionsProvider);
}

/// Whether the balance is masked on the home card; remembered across launches.
final walletBalanceHiddenProvider =
    StateNotifierProvider<WalletBalanceHiddenNotifier, bool>(
      (ref) => WalletBalanceHiddenNotifier(),
    );

class WalletBalanceHiddenNotifier extends StateNotifier<bool> {
  WalletBalanceHiddenNotifier() : super(false) {
    _storage.read(key: _key).then((value) {
      if (mounted && value != null) state = value == '1';
    }).catchError((_) {});
  }

  static const _key = 'wallet_balance_hidden';
  final _storage = const FlutterSecureStorage();

  void toggle() {
    state = !state;
    _storage.write(key: _key, value: state ? '1' : '0').catchError((_) {});
  }
}
