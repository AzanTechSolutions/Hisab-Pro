/// Financial category domain entity.
class Category {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type, // income, expense, transfer, loan, custom
    this.colorHex,
    this.iconKey,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String type;
  final String? colorHex;
  final String? iconKey;
  final bool isDefault;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  Category copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? colorHex,
    String? iconKey,
    bool? isDefault,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      colorHex: colorHex ?? this.colorHex,
      iconKey: iconKey ?? this.iconKey,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'color_hex': colorHex,
      'icon_key': iconKey,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      colorHex: map['color_hex'] as String?,
      iconKey: map['icon_key'] as String?,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

