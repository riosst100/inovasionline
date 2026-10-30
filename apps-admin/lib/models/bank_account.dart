class BankAccount {
  const BankAccount({
    required this.id,
    required this.type,
    required this.name,
    required this.isEnabled,
    required this.sortOrder,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
    this.description,
    this.instructions,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
    id: json['id'] as String,
    type: (json['type'] as String?) == 'ewallet' ? 'ewallet' : 'bank_transfer',
    name: json['name'] as String? ?? '',
    bankName: json['bank_name'] as String?,
    accountNumber: json['account_number'] as String?,
    accountHolderName: json['account_holder_name'] as String?,
    description: json['description'] as String?,
    instructions: json['instructions'] as String?,
    isEnabled: json['is_enabled'] as bool? ?? true,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String type;
  final String name;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;
  final String? description;
  final String? instructions;
  final bool isEnabled;
  final int sortOrder;

  bool get isEwallet => type == 'ewallet';

  String get displayName => (bankName != null && bankName!.trim().isNotEmpty) ? bankName! : name;
}

class BankAccountInput {
  const BankAccountInput({
    required this.type,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolderName,
    this.description,
    this.instructions,
    this.isEnabled = true,
  });

  final String type;
  final String bankName;
  final String accountNumber;
  final String accountHolderName;
  final String? description;
  final String? instructions;
  final bool isEnabled;

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': bankName,
    'bank_name': bankName,
    'account_number': accountNumber,
    'account_holder_name': accountHolderName,
    'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
    'instructions': (instructions?.trim().isEmpty ?? true) ? null : instructions!.trim(),
    'is_enabled': isEnabled,
  };
}

