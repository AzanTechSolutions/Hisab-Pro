/// Person or contact domain entity.
class Person {
  const Person({
    required this.id,
    required this.userId,
    required this.fullName,
    this.phoneNumber,
    this.address,
    this.notes,
    this.profileImagePath,
    required this.createdAt,
    required this.updatedAt,
    this.totalLentMinor = 0,
    this.totalBorrowedMinor = 0,
    this.outstandingReceivableMinor = 0,
    this.outstandingPayableMinor = 0,
  });

  final String id;
  final String userId;
  final String fullName;
  final String? phoneNumber;
  final String? address;
  final String? notes;
  final String? profileImagePath;
  final int createdAt;
  final int updatedAt;

  // Derived financial exposures
  final int totalLentMinor;
  final int totalBorrowedMinor;
  final int outstandingReceivableMinor;
  final int outstandingPayableMinor;

  int get netBalanceMinor => outstandingReceivableMinor - outstandingPayableMinor;

  Person copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? phoneNumber,
    String? address,
    String? notes,
    String? profileImagePath,
    int? createdAt,
    int? updatedAt,
    int? totalLentMinor,
    int? totalBorrowedMinor,
    int? outstandingReceivableMinor,
    int? outstandingPayableMinor,
  }) {
    return Person(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalLentMinor: totalLentMinor ?? this.totalLentMinor,
      totalBorrowedMinor: totalBorrowedMinor ?? this.totalBorrowedMinor,
      outstandingReceivableMinor: outstandingReceivableMinor ?? this.outstandingReceivableMinor,
      outstandingPayableMinor: outstandingPayableMinor ?? this.outstandingPayableMinor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'address': address,
      'notes': notes,
      'profile_image_path': profileImagePath,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String,
      phoneNumber: map['phone_number'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      profileImagePath: map['profile_image_path'] as String?,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      totalLentMinor: map['total_lent_minor'] as int? ?? 0,
      totalBorrowedMinor: map['total_borrowed_minor'] as int? ?? 0,
      outstandingReceivableMinor: map['outstanding_receivable_minor'] as int? ?? 0,
      outstandingPayableMinor: map['outstanding_payable_minor'] as int? ?? 0,
    );
  }
}

