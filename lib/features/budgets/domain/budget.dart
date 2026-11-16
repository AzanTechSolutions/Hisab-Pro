/// Budget and category allocation domain entities.
class Budget {
  const Budget({
    required this.id,
    required this.userId,
    required this.name,
    required this.budgetMonth, // 1 to 12
    required this.budgetYear, // e.g. 2026
    required this.totalLimitMinor,
    this.currency = 'PKR',
    this.notificationThresholdPercent = 80,
    required this.createdAt,
    required this.updatedAt,
    this.spentMinor = 0,
    this.categoryAllocations = const [],
  });

  final String id;
  final String userId;
  final String name;
  final int budgetMonth;
  final int budgetYear;
  final int totalLimitMinor;
  final String currency;
  final int notificationThresholdPercent;
  final int createdAt;
  final int updatedAt;

  // Derived live metrics
  final int spentMinor;
  final List<BudgetCategoryAllocation> categoryAllocations;

  int get remainingMinor {
    final rem = totalLimitMinor - spentMinor;
    return rem > 0 ? rem : 0;
  }

  double get utilizationPercentage {
    if (totalLimitMinor <= 0) return 0.0;
    return (spentMinor / totalLimitMinor) * 100.0;
  }

  double get progress {
    if (totalLimitMinor <= 0) return 0.0;
    final p = spentMinor / totalLimitMinor;
    return p > 1.0 ? 1.0 : p;
  }

  bool get isOverBudget => spentMinor > totalLimitMinor;
  bool get isWarning => utilizationPercentage >= notificationThresholdPercent && !isOverBudget;

  Budget copyWith({
    String? id,
    String? userId,
    String? name,
    int? budgetMonth,
    int? budgetYear,
    int? totalLimitMinor,
    String? currency,
    int? notificationThresholdPercent,
    int? createdAt,
    int? updatedAt,
    int? spentMinor,
    List<BudgetCategoryAllocation>? categoryAllocations,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      budgetMonth: budgetMonth ?? this.budgetMonth,
      budgetYear: budgetYear ?? this.budgetYear,
      totalLimitMinor: totalLimitMinor ?? this.totalLimitMinor,
      currency: currency ?? this.currency,
      notificationThresholdPercent: notificationThresholdPercent ?? this.notificationThresholdPercent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      spentMinor: spentMinor ?? this.spentMinor,
      categoryAllocations: categoryAllocations ?? this.categoryAllocations,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'budget_month': budgetMonth,
      'budget_year': budgetYear,
      'total_limit_minor': totalLimitMinor,
      'currency': currency,
      'notification_threshold_percent': notificationThresholdPercent,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map, {int spentMinor = 0, List<BudgetCategoryAllocation> allocations = const []}) {
    return Budget(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      budgetMonth: map['budget_month'] as int,
      budgetYear: map['budget_year'] as int,
      totalLimitMinor: map['total_limit_minor'] as int? ?? 0,
      currency: map['currency'] as String? ?? 'PKR',
      notificationThresholdPercent: map['notification_threshold_percent'] as int? ?? 80,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      spentMinor: spentMinor,
      categoryAllocations: allocations,
    );
  }
}

class BudgetCategoryAllocation {
  const BudgetCategoryAllocation({
    required this.id,
    required this.userId,
    required this.budgetId,
    required this.categoryId,
    required this.limitMinor,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    this.spentMinor = 0,
  });

  final String id;
  final String userId;
  final String budgetId;
  final String categoryId;
  final int limitMinor;
  final int createdAt;
  final int updatedAt;

  // Joined display attributes
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final int spentMinor;

  int get remainingMinor {
    final rem = limitMinor - spentMinor;
    return rem > 0 ? rem : 0;
  }

  double get progress {
    if (limitMinor <= 0) return 0.0;
    final p = spentMinor / limitMinor;
    return p > 1.0 ? 1.0 : p;
  }

  bool get isOverBudget => spentMinor > limitMinor;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'budget_id': budgetId,
      'category_id': categoryId,
      'limit_minor': limitMinor,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory BudgetCategoryAllocation.fromMap(Map<String, dynamic> map, {int spentMinor = 0}) {
    return BudgetCategoryAllocation(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      budgetId: map['budget_id'] as String,
      categoryId: map['category_id'] as String,
      limitMinor: map['limit_minor'] as int? ?? 0,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as String?,
      categoryIcon: map['category_icon'] as String?,
      spentMinor: spentMinor,
    );
  }
}

