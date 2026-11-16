/// Represents an isolated local user profile on the device.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarPath,
    this.biometricEnabled = false,
    this.lockEnabled = true,
    this.inactivityTimeoutMinutes = 5,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  final String id;
  final String username;
  final String fullName;
  final String? avatarPath;
  final bool biometricEnabled;
  final bool lockEnabled;
  final int inactivityTimeoutMinutes;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final int? lastLoginAt;

  UserProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarPath,
    bool? biometricEnabled,
    bool? lockEnabled,
    int? inactivityTimeoutMinutes,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
    int? lastLoginAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarPath: avatarPath ?? this.avatarPath,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      inactivityTimeoutMinutes: inactivityTimeoutMinutes ?? this.inactivityTimeoutMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_path': avatarPath,
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'lock_enabled': lockEnabled ? 1 : 0,
      'inactivity_timeout_minutes': inactivityTimeoutMinutes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_login_at': lastLoginAt,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      avatarPath: map['avatar_path'] as String?,
      biometricEnabled: (map['biometric_enabled'] as int? ?? 0) == 1,
      lockEnabled: (map['lock_enabled'] as int? ?? 1) == 1,
      inactivityTimeoutMinutes: map['inactivity_timeout_minutes'] as int? ?? 5,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      lastLoginAt: map['last_login_at'] as int?,
    );
  }

  Map<String, dynamic> toCatalogMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_path': avatarPath,
      'biometric_enabled': biometricEnabled,
      'created_at': createdAt,
    };
  }

  factory UserProfile.fromCatalogMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      avatarPath: map['avatar_path'] as String?,
      biometricEnabled: map['biometric_enabled'] as bool? ?? false,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
