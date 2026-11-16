/// Financial account domain entity.
class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,
    this.currency = 'PKR',
    this.openingBalanceMinor = 0,
    this.currentBalanceMinor = 0,
    this.isArchived = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String accountType; // cash, bank, wallet, savings, other
  final String currency;
  final int openingBalanceMinor;
  final int currentBalanceMinor;
  final bool isArchived;
  final String? notes;
  final int createdAt;
  final int updatedAt;

  Account copyWith({
    String? id,
    String? userId,
    String? name,
    String? accountType,
    String? currency,
    int? openingBalanceMinor,
    int? currentBalanceMinor,
    bool? isArchived,
    String? notes,
    int? createdAt,
    int? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      currency: currency ?? this.currency,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      currentBalanceMinor: currentBalanceMinor ?? this.currentBalanceMinor,
      isArchived: isArchived ?? this.isArchived,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'account_type': accountType,
      'currency': currency,
      'opening_balance_minor': openingBalanceMinor,
      'current_balance_minor': currentBalanceMinor,
      'is_archived': isArchived ? 1 : 0,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      accountType: map['account_type'] as String,
      currency: map['currency'] as String? ?? 'PKR',
      openingBalanceMinor: map['opening_balance_minor'] as int? ?? 0,
      currentBalanceMinor: map['current_balance_minor'] as int? ?? 0,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

