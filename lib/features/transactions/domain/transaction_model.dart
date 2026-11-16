/// Financial transaction domain entity for ledger records.
class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.userId,
    required this.accountId,
    this.categoryId,
    this.personId,
    required this.type, // income, expense, adjustment, reversal
    required this.title,
    required this.amountMinor,
    this.paymentMethod,
    required this.transactionDate,
    this.transactionTime,
    this.notes,
    this.attachmentId,
    this.status = 'posted', // posted, reversed, void
    required this.createdAt,
    required this.updatedAt,
    this.accountName,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
  });

  final String id;
  final String userId;
  final String accountId;
  final String? categoryId;
  final String? personId;
  final String type;
  final String title;
  final int amountMinor;
  final String? paymentMethod;
  final int transactionDate;
  final int? transactionTime;
  final String? notes;
  final String? attachmentId;
  final String status;
  final int createdAt;
  final int updatedAt;

  // Joined display attributes (not stored directly in transactions table)
  final String? accountName;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isReversal => type == 'reversal';
  bool get isPosted => status == 'posted';

  FinancialTransaction copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? categoryId,
    String? personId,
    String? type,
    String? title,
    int? amountMinor,
    String? paymentMethod,
    int? transactionDate,
    int? transactionTime,
    String? notes,
    String? attachmentId,
    String? status,
    int? createdAt,
    int? updatedAt,
    String? accountName,
    String? categoryName,
    String? categoryColor,
    String? categoryIcon,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      personId: personId ?? this.personId,
      type: type ?? this.type,
      title: title ?? this.title,
      amountMinor: amountMinor ?? this.amountMinor,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionTime: transactionTime ?? this.transactionTime,
      notes: notes ?? this.notes,
      attachmentId: attachmentId ?? this.attachmentId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accountName: accountName ?? this.accountName,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      categoryIcon: categoryIcon ?? this.categoryIcon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'account_id': accountId,
      'category_id': categoryId,
      'person_id': personId,
      'type': type,
      'title': title,
      'amount_minor': amountMinor,
      'payment_method': paymentMethod,
      'transaction_date': transactionDate,
      'transaction_time': transactionTime,
      'notes': notes,
      'attachment_id': attachmentId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      accountId: map['account_id'] as String,
      categoryId: map['category_id'] as String?,
      personId: map['person_id'] as String?,
      type: map['type'] as String,
      title: map['title'] as String,
      amountMinor: map['amount_minor'] as int? ?? 0,
      paymentMethod: map['payment_method'] as String?,
      transactionDate: map['transaction_date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      transactionTime: map['transaction_time'] as int?,
      notes: map['notes'] as String?,
      attachmentId: map['attachment_id'] as String?,
      status: map['status'] as String? ?? 'posted',
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      accountName: map['account_name'] as String?,
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as String?,
      categoryIcon: map['category_icon'] as String?,
    );
  }
}

