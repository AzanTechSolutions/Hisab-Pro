import 'dart:convert';

/// Represents metadata for an encrypted Hisab Pro backup archive.
class BackupManifest {
  const BackupManifest({
    required this.manifestVersion,
    required this.profileId,
    required this.profileName,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.salt,
    required this.checksum,
    required this.tableCounts,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      manifestVersion: json['manifestVersion'] as int? ?? 1,
      profileId: json['profileId'] as String,
      profileName: json['profileName'] as String? ?? 'Default Profile',
      createdAt: DateTime.parse(json['createdAt'] as String),
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      salt: json['salt'] as String,
      checksum: json['checksum'] as String,
      tableCounts: (json['tableCounts'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  final int manifestVersion;
  final String profileId;
  final String profileName;
  final DateTime createdAt;
  final String appVersion;
  final int schemaVersion;
  final String salt;
  final String checksum;
  final Map<String, int> tableCounts;

  int get totalRecords => tableCounts.values.fold(0, (sum, count) => sum + count);

  Map<String, dynamic> toJson() {
    return {
      'manifestVersion': manifestVersion,
      'profileId': profileId,
      'profileName': profileName,
      'createdAt': createdAt.toIso8601String(),
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
      'salt': salt,
      'checksum': checksum,
      'tableCounts': tableCounts,
    };
  }

  String toEncodedJson() => base64UrlEncode(utf8.encode(jsonEncode(toJson())));

  static BackupManifest fromEncodedJson(String encoded) {
    final decoded = utf8.decode(base64Url.decode(encoded));
    final map = jsonDecode(decoded) as Map<String, dynamic>;
    return BackupManifest.fromJson(map);
  }
}

