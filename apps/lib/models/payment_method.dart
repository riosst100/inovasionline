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

  /// Section heading in the checkout picker.
  bool get isWallet => type == 'wallet';

  String get group {
    if (isWallet) return 'Saldo';
    if (type != 'payment_gateway') return 'Lainnya';
    final channel = gatewayChannel;
    if (channel == null) return 'Pembayaran Online';
    if (channel == 'other_qris' || channel == 'gopay' || channel == 'shopeepay') return 'E-Wallet & QRIS';
    if (channel.endsWith('_va') || channel == 'echannel') return 'Virtual Account';
    return 'Kartu';
  }
}
