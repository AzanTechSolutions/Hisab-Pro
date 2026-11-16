/// Loan domain entity holding principal and repayment state.
class Loan {
  const Loan({
    required this.id,
    required this.userId,
    required this.personId,
    required this.loanType, // 'loan_given' or 'loan_taken'
    required this.amountMinor,
    this.interestRatePercent = 0.0,
    required this.loanDate,
    this.dueDate,
    this.description,
    this.notes,
    required this.accountId,
    this.status = 'active', // active, partial, overdue, paid, closed
    required this.createdAt,
    required this.updatedAt,
    this.personName,
    this.personPhone,
    this.accountName,
    this.totalRepaidMinor = 0,
  });

  final String id;
  final String userId;
  final String personId;
  final String loanType;
  final int amountMinor;
  final double interestRatePercent;
  final int loanDate;
  final int? dueDate;
  final String? description;
  final String? notes;
  final String accountId;
  final String status;
  final int createdAt;
  final int updatedAt;

  // Joined display attributes
  final String? personName;
  final String? personPhone;
  final String? accountName;
  final int totalRepaidMinor;

  bool get isGiven => loanType == 'loan_given';
  bool get isTaken => loanType == 'loan_taken';
  bool get isPaid => status == 'paid' || remainingBalanceMinor <= 0;

  int get remainingBalanceMinor {
    final rem = amountMinor - totalRepaidMinor;
    return rem > 0 ? rem : 0;
  }

  double get repaymentProgress {
    if (amountMinor <= 0) return 1.0;
    final progress = totalRepaidMinor / amountMinor;
    return progress > 1.0 ? 1.0 : progress;
  }

  bool get isOverdue {
    if (isPaid) return false;
    if (dueDate == null) return false;
    return DateTime.now().millisecondsSinceEpoch > dueDate!;
  }

  Loan copyWith({
    String? id,
    String? userId,
    String? personId,
    String? loanType,
    int? amountMinor,
    double? interestRatePercent,
    int? loanDate,
    int? dueDate,
    String? description,
    String? notes,
    String? accountId,
    String? status,
    int? createdAt,
    int? updatedAt,
    String? personName,
    String? personPhone,
    String? accountName,
    int? totalRepaidMinor,
  }) {
    return Loan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      personId: personId ?? this.personId,
      loanType: loanType ?? this.loanType,
      amountMinor: amountMinor ?? this.amountMinor,
      interestRatePercent: interestRatePercent ?? this.interestRatePercent,
      loanDate: loanDate ?? this.loanDate,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      accountId: accountId ?? this.accountId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      personName: personName ?? this.personName,
      personPhone: personPhone ?? this.personPhone,
      accountName: accountName ?? this.accountName,
      totalRepaidMinor: totalRepaidMinor ?? this.totalRepaidMinor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'person_id': personId,
      'loan_type': loanType,
      'amount_minor': amountMinor,
      'interest_rate_percent': interestRatePercent,
      'loan_date': loanDate,
      'due_date': dueDate,
      'description': description,
      'notes': notes,
      'account_id': accountId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      personId: map['person_id'] as String,
      loanType: map['loan_type'] as String,
      amountMinor: map['amount_minor'] as int? ?? 0,
      interestRatePercent: (map['interest_rate_percent'] as num?)?.toDouble() ?? 0.0,
      loanDate: map['loan_date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      dueDate: map['due_date'] as int?,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      accountId: map['account_id'] as String,
      status: map['status'] as String? ?? 'active',
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      personName: map['person_name'] as String?,
      personPhone: map['person_phone'] as String?,
      accountName: map['account_name'] as String?,
      totalRepaidMinor: map['total_repaid_minor'] as int? ?? 0,
    );
  }
}

