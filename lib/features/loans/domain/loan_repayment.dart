/// Repayment event domain entity linked to an original loan.
class LoanRepayment {
  const LoanRepayment({
    required this.id,
    required this.userId,
    required this.loanId,
    required this.repaymentDate,
    required this.amountMinor,
    required this.accountId,
    this.notes,
    this.paymentMethod,
    this.status = 'posted', // posted, reversed
    required this.createdAt,
    required this.updatedAt,
    this.accountName,
  });

  final String id;
  final String userId;
  final String loanId;
  final int repaymentDate;
  final int amountMinor;
  final String accountId;
  final String? notes;
  final String? paymentMethod;
  final String status;
  final int createdAt;
  final int updatedAt;

  // Joined display attribute
  final String? accountName;

  bool get isPosted => status == 'posted';

  LoanRepayment copyWith({
    String? id,
    String? userId,
    String? loanId,
    int? repaymentDate,
    int? amountMinor,
    String? accountId,
    String? notes,
    String? paymentMethod,
    String? status,
    int? createdAt,
    int? updatedAt,
    String? accountName,
  }) {
    return LoanRepayment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      loanId: loanId ?? this.loanId,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      amountMinor: amountMinor ?? this.amountMinor,
      accountId: accountId ?? this.accountId,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accountName: accountName ?? this.accountName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'loan_id': loanId,
      'repayment_date': repaymentDate,
      'amount_minor': amountMinor,
      'account_id': accountId,
      'notes': notes,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory LoanRepayment.fromMap(Map<String, dynamic> map) {
    return LoanRepayment(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      loanId: map['loan_id'] as String,
      repaymentDate: map['repayment_date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      amountMinor: map['amount_minor'] as int? ?? 0,
      accountId: map['account_id'] as String,
      notes: map['notes'] as String?,
      paymentMethod: map['payment_method'] as String?,
      status: map['status'] as String? ?? 'posted',
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      accountName: map['account_name'] as String?,
    );
  }
}

