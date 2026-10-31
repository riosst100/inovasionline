double _toDouble(Object? value) => double.tryParse(value.toString()) ?? 0;

/// The buyer's balance ("Saldo Inovasi") plus the server's top-up limits.
class WalletSummary {
  WalletSummary({
    required this.balance,
    required this.topupMin,
    required this.topupMax,
    required this.maxBalance,
    this.bonusMax = 0,
    this.bonusAvailable = false,
    this.bonusRequiresAd = false,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
    balance: _toDouble(json['balance']),
    topupMin: json['topup_min'] as int? ?? 10000,
    topupMax: json['topup_max'] as int? ?? 2000000,
    maxBalance: json['max_balance'] as int? ?? 0,
    bonusMax: json['bonus_max'] as int? ?? 0,
    bonusAvailable: json['bonus_available'] as bool? ?? false,
    bonusRequiresAd: json['bonus_requires_ad'] as bool? ?? false,
  );

  final double balance;
  final int topupMin;
  final int topupMax;

  /// 0 means no cap.
  final int maxBalance;

  /// One-time "saldo belanja" bonus (random, up to [bonusMax]), claimable while [bonusAvailable].
  final int bonusMax;
  final bool bonusAvailable;

  /// Admin requires a fully watched rewarded ad before the bonus can be claimed.
  final bool bonusRequiresAd;

  /// Largest top-up that still fits under [maxBalance].
  int get topupRoom {
    if (maxBalance <= 0) return topupMax;
    final room = maxBalance - balance.floor();
    return room < topupMax ? (room < 0 ? 0 : room) : topupMax;
  }
}

class WalletTransaction {
  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
    this.orderId,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: _toDouble(json['amount']),
        balanceAfter: _toDouble(json['balance_after']),
        description: json['description'] as String? ?? '',
        orderId: json['order_id'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );

  /// topup | payment | refund | adjustment | bonus
  final String type;
  final String id;

  /// Signed: positive credits, negative debits.
  final double amount;
  final double balanceAfter;
  final String description;
  final String? orderId;
  final DateTime createdAt;

  String get typeLabel => switch (type) {
    'topup' => 'Top Up',
    'payment' => 'Pembayaran',
    'refund' => 'Pengembalian Dana',
    'adjustment' => 'Penyesuaian',
    'bonus' => 'Bonus Saldo',
    'ad_chest' => 'Hadiah Peti',
    _ => type,
  };
}

class WalletTopup {
  WalletTopup({
    required this.id,
    required this.topupNumber,
    required this.amount,
    required this.status,
    this.paymentRedirectUrl,
  });

  factory WalletTopup.fromJson(Map<String, dynamic> json) => WalletTopup(
    id: json['id'] as String,
    topupNumber: json['topup_number'] as String,
    amount: _toDouble(json['amount']),
    status: json['status'] as String,
    paymentRedirectUrl: json['payment_redirect_url'] as String?,
  );

  final String id;
  final String topupNumber;
  final double amount;

  /// pending | paid | failed | expired
  final String status;
  final String? paymentRedirectUrl;

  bool get isPaid => status == 'paid';
}
