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

/// The home screen's daily reward chests: each opens with one rewarded ad
/// for a random saldo amount (up to [maxAmount]).
class AdChestStatus {
  AdChestStatus({
    required this.openedToday,
    required this.chestsPerDay,
    required this.maxAmount,
    required this.doneToday,
    required this.soldOut,
  });

  factory AdChestStatus.fromJson(Map<String, dynamic> json) => AdChestStatus(
    openedToday: json['opened_today'] as int? ?? 0,
    chestsPerDay: json['chests_per_day'] as int? ?? 0,
    maxAmount: json['max_amount'] as int? ?? 0,
    doneToday: json['done_today'] as bool? ?? false,
    soldOut: json['sold_out'] as bool? ?? false,
  );

  final int openedToday;
  final int chestsPerDay;
  final int maxAmount;

  /// All of today's chests are opened; back tomorrow.
  final bool doneToday;

  /// Today's prize budget is used up; back tomorrow.
  final bool soldOut;

  int get remaining => (chestsPerDay - openedToday).clamp(0, chestsPerDay);
  bool get canOpen => !doneToday && !soldOut && remaining > 0;
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
