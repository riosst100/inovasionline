class PaymentMethod {
  PaymentMethod({
    required this.id,
    required this.storeId,
    required this.type,
    required this.name,
    required this.isEnabled,
    required this.sortOrder,
    this.description,
    this.instructions,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        type: json['type'] as String,
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
  final String storeId;
  final String type;
  final String name;
  final String? description;
  final String? instructions;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;
  final bool isEnabled;
  final int sortOrder;
}
