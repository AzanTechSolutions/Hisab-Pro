/// Account-to-account transfer domain entity.
class AccountTransfer {
  const AccountTransfer({
    required this.id,
    required this.userId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountMinor,
    required this.transferDate,
    this.note,
    this.status = 'posted', // posted, reversed
    required this.createdAt,
    required this.updatedAt,
    this.fromAccountName,
    this.toAccountName,
  });

  final String id;
  final String userId;
  final String fromAccountId;
  final String toAccountId;
  final int amountMinor;
  final int transferDate;
  final String? note;
  final String status;
  final int createdAt;
  final int updatedAt;

  // Joined display attributes
  final String? fromAccountName;
  final String? toAccountName;

  bool get isPosted => status == 'posted';

  AccountTransfer copyWith({
    String? id,
    String? userId,
    String? fromAccountId,
    String? toAccountId,
    int? amountMinor,
    int? transferDate,
    String? note,
    String? status,
    int? createdAt,
    int? updatedAt,
    String? fromAccountName,
    String? toAccountName,
  }) {
    return AccountTransfer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amountMinor: amountMinor ?? this.amountMinor,
      transferDate: transferDate ?? this.transferDate,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fromAccountName: fromAccountName ?? this.fromAccountName,
      toAccountName: toAccountName ?? this.toAccountName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'amount_minor': amountMinor,
      'transfer_date': transferDate,
      'note': note,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory AccountTransfer.fromMap(Map<String, dynamic> map) {
    return AccountTransfer(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      fromAccountId: map['from_account_id'] as String,
      toAccountId: map['to_account_id'] as String,
      amountMinor: map['amount_minor'] as int? ?? 0,
      transferDate: map['transfer_date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      note: map['note'] as String?,
      status: map['status'] as String? ?? 'posted',
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      fromAccountName: map['from_account_name'] as String?,
      toAccountName: map['to_account_name'] as String?,
    );
  }
}

