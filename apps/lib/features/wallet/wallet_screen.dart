import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/wallet.dart';
import 'wallet_providers.dart';

/// "Saldo Inovasi": balance, top-up entry point and the ledger.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Saldo Inovasi')),
      body: RefreshIndicator(
        onRefresh: () async {
          invalidateWalletFromWidget(ref);
          await ref.read(walletTransactionsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _BalanceCard(
              balance: walletAsync.valueOrNull?.balance,
              onTopUp: () => context.push('/wallet/topup'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Saldo hanya bisa dipakai untuk belanja di Inovasi Online dan tidak dapat ditarik. '
              'Pesanan yang dibatalkan setelah dibayar otomatis dikembalikan ke saldo.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.mutedForeground,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Riwayat Transaksi',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            transactionsAsync.when(
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Belum ada transaksi.',
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 60),
                            _TransactionTile(transaction: items[i]),
                          ],
                        ],
                      ),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Gagal memuat riwayat. Tarik untuk mencoba lagi.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onTopUp});

  final double? balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saldo kamu',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  balance == null ? '—' : formatCurrency(balance!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onTopUp,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0284C7),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Top Up',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  static final _dateFormat = DateFormat('d MMM yyyy, HH.mm', 'id_ID');

  @override
  Widget build(BuildContext context) {
    final credit = transaction.amount >= 0;
    final (icon, color) = switch (transaction.type) {
      'topup' => (Icons.add_card_rounded, AppColors.primary),
      'payment' => (Icons.shopping_bag_rounded, const Color(0xFF0284C7)),
      'refund' => (Icons.replay_rounded, AppColors.success),
      'bonus' => (Icons.card_giftcard_rounded, const Color(0xFFD97706)),
      _ => (Icons.tune_rounded, AppColors.secondary),
    };

    return InkWell(
      onTap: transaction.orderId == null
          ? null
          : () => context.push('/orders/${transaction.orderId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.typeLabel,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  Text(
                    _dateFormat.format(transaction.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${credit ? '+' : '−'}${formatCurrency(transaction.amount.abs())}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: credit ? AppColors.success : AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
