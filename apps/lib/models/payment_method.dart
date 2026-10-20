class PaymentMethod {
  PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    required this.isEnabled,
    required this.sortOrder,
    this.gatewayChannel,
    this.description,
    this.instructions,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
    this.paylater,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: json['id'] as String,
    type: json['type'] as String,
    gatewayChannel: json['gateway_channel'] as String?,
    name: json['name'] as String,
    description: json['description'] as String?,
    instructions: json['instructions'] as String?,
    bankName: json['bank_name'] as String?,
    accountNumber: json['account_number'] as String?,
    accountHolderName: json['account_holder_name'] as String?,
    isEnabled: json['is_enabled'] as bool? ?? true,
    sortOrder: json['sort_order'] as int? ?? 0,
    paylater: json['paylater'] is Map<String, dynamic>
        ? PaylaterEligibility.fromJson(json['paylater'] as Map<String, dynamic>)
        : null,
  );

  final String id;
  final String type;

  /// Midtrans channel (gopay, bca_va, ...) for payment_gateway methods; null lets the buyer pick on Midtrans.
  final String? gatewayChannel;
  final String name;
  final String? description;
  final String? instructions;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;
  final bool isEnabled;
  final int sortOrder;

  /// Only set on the paylater method for a logged-in buyer.
  final PaylaterEligibility? paylater;

  /// Section heading in the checkout picker.
  bool get isWallet => type == 'wallet';
  bool get isPaylater => type == 'paylater';

  /// COD and Paylater share the one-time face check.
  bool get needsFaceVerification => isCod || isPaylater;

  /// Cash on delivery; the backend calls it cash_on_delivery.
  bool get isCod => type == 'cod' || type == 'cash_on_delivery';

  String get group {
    if (isWallet) return 'Saldo';
    if (isCod) return 'Bayar di Tempat';
    if (type != 'payment_gateway') return 'Lainnya';
    final channel = gatewayChannel;
    if (channel == null) return 'Pembayaran Online';
    if (channel == 'other_qris' || channel == 'gopay' || channel == 'shopeepay')
      return 'E-Wallet & QRIS';
    if (channel.endsWith('_va') || channel == 'echannel')
      return 'Virtual Account';
    return 'Kartu';
  }
}

/// Whether the buyer has completed enough transactions to use Paylater.
class PaylaterEligibility {
  const PaylaterEligibility({
    required this.available,
    required this.requiredTransactions,
    required this.completedTransactions,
    required this.requiresVerification,
    this.reason,
  });

  factory PaylaterEligibility.fromJson(Map<String, dynamic> json) =>
      PaylaterEligibility(
        available: json['available'] as bool? ?? false,
        reason: json['reason'] as String?,
        requiredTransactions: json['required_transactions'] as int? ?? 0,
        completedTransactions: json['completed_transactions'] as int? ?? 0,
        requiresVerification: json['requires_verification'] as bool? ?? false,
      );

  final bool available;
  final String? reason;
  final int requiredTransactions;
  final int completedTransactions;

  /// First use needs the one-time face verification.
  final bool requiresVerification;
}
