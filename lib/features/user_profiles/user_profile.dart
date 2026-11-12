class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.biometricEnabled,
  });

  final String id;
  final String username;
  final String fullName;
  final bool biometricEnabled;
}
