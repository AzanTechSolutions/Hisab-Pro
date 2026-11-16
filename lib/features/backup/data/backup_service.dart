import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hisab_pro/core/database/database_service.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';
import 'package:hisab_pro/core/security/key_derivation_service.dart';
import 'package:hisab_pro/features/backup/domain/backup_manifest.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => 'BackupException: $message';
}

/// Service providing encrypted export, verification, and restoration of Hisab Pro profiles.
class BackupService {
  BackupService({
    required DatabaseService databaseService,
    required KeyDerivationService keyDerivation,
  })  : _databaseService = databaseService,
        _keyDerivation = keyDerivation;

  final DatabaseService _databaseService;
  final KeyDerivationService _keyDerivation;

  static const String _containerHeader = 'HISAB_BACKUP_CONTAINER_V1';
  static const String _payloadDelimiter = '---HISAB_PAYLOAD---';
  static const String _hmacDelimiter = '---HISAB_HMAC---';

  static const List<String> _exportTables = [
    'accounts',
    'categories',
    'people',
    'attachments',
    'transactions',
    'transfers',
    'loans',
    'loan_repayments',
    'budgets',
    'budget_categories',
    'reminders',
    'app_settings',
  ];

  /// Exports an authenticated, encrypted `.hisab` backup file.
  Future<File> createEncryptedBackup({
    required String profileId,
    required String profileName,
    required String backupPassword,
    String? targetDirectoryPath,
  }) async {
    if (backupPassword.length < 6) {
      throw BackupException('Backup password must be at least 6 characters.');
    }

    final db = _databaseService.getActiveDatabase(profileId);
    final Map<String, List<Map<String, dynamic>>> fullData = {};
    final Map<String, int> tableCounts = {};

    for (final table in _exportTables) {
      final rows = await db.query(table);
      fullData[table] = rows;
      tableCounts[table] = rows.length;
    }

    final Map<String, dynamic> rawExport = {
      'profileId': profileId,
      'profileName': profileName,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': fullData,
    };

    final jsonString = jsonEncode(rawExport);
    final jsonBytes = utf8.encode(jsonString);
    final rawChecksum = sha256.convert(jsonBytes).toString();

    final salt = _keyDerivation.buildSalt();
    final derivedKeyBase64 = await _keyDerivation.derivePasswordKey(
      password: backupPassword,
      salt: salt,
      length: 32,
    );
    final derivedKeyBytes = base64Url.decode(derivedKeyBase64);

    final encKey = derivedKeyBytes.sublist(0, 16);
    final hmacKey = derivedKeyBytes.sublist(16, 32);

    final cipherBytes = _cryptStream(jsonBytes, encKey, base64Url.decode(salt));
    final cipherBase64 = base64UrlEncode(cipherBytes);

    final manifest = BackupManifest(
      manifestVersion: 1,
      profileId: profileId,
      profileName: profileName,
      createdAt: DateTime.now().toUtc(),
      appVersion: '1.0.0',
      schemaVersion: 1,
      salt: salt,
      checksum: rawChecksum,
      tableCounts: tableCounts,
    );

    final manifestBase64 = manifest.toEncodedJson();
    final hmacDigest = Hmac(sha256, hmacKey).convert(
      utf8.encode('$manifestBase64.$cipherBase64'),
    ).toString();

    final containerContent = [
      _containerHeader,
      manifestBase64,
      _payloadDelimiter,
      cipherBase64,
      _hmacDelimiter,
      hmacDigest,
    ].join('\n');

    String targetDir = targetDirectoryPath ?? '';
    if (targetDir.isEmpty) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        targetDir = docDir.path;
      } catch (_) {
        targetDir = Directory.current.path;
      }
    }

    final safeTimestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final filePath = '$targetDir/hisab_backup_${profileId}_$safeTimestamp.hisab';
    final backupFile = File(filePath);
    await backupFile.writeAsString(containerContent, flush: true);

    AppLogger.info('Encrypted backup created successfully: $filePath (${backupFile.lengthSync()} bytes)');
    return backupFile;
  }

  /// Verifies the authenticity and password of a backup file, returning the manifest without modifying the database.
  Future<BackupManifest> verifyBackup({
    required String fileContent,
    required String backupPassword,
  }) async {
    final parsed = _parseContainer(fileContent);
    final manifest = BackupManifest.fromEncodedJson(parsed['manifest']!);

    final derivedKeyBase64 = await _keyDerivation.derivePasswordKey(
      password: backupPassword,
      salt: manifest.salt,
      length: 32,
    );
    final derivedKeyBytes = base64Url.decode(derivedKeyBase64);
    final encKey = derivedKeyBytes.sublist(0, 16);
    final hmacKey = derivedKeyBytes.sublist(16, 32);

    // Verify HMAC
    final expectedHmac = Hmac(sha256, hmacKey).convert(
      utf8.encode('${parsed['manifest']!}.${parsed['payload']!}'),
    ).toString();

    if (expectedHmac != parsed['hmac']) {
      throw BackupException('Invalid backup password or file has been corrupted/tampered with.');
    }

    // Decrypt and verify checksum
    final cipherBytes = base64Url.decode(parsed['payload']!);
    final decryptedBytes = _cryptStream(cipherBytes, encKey, base64Url.decode(manifest.salt));
    final calculatedChecksum = sha256.convert(decryptedBytes).toString();

    if (calculatedChecksum != manifest.checksum) {
      throw BackupException('Integrity checksum mismatch in backup payload.');
    }

    return manifest;
  }

  /// Restores records from a verified encrypted backup.
  /// Validates integrity before and after restoration using `PRAGMA integrity_check`.
  Future<Map<String, dynamic>> restoreBackup({
    required String fileContent,
    required String backupPassword,
    required String currentProfileId,
    bool createSafetyBackup = true,
  }) async {
    final manifest = await verifyBackup(
      fileContent: fileContent,
      backupPassword: backupPassword,
    );

    // Optional safety backup of active database before overwrite
    File? safetyBackupFile;
    if (createSafetyBackup) {
      try {
        safetyBackupFile = await createEncryptedBackup(
          profileId: currentProfileId,
          profileName: 'Auto Safety Backup Before Restore',
          backupPassword: backupPassword,
        );
        AppLogger.info('Safety backup created prior to restore: ${safetyBackupFile.path}');
      } catch (e) {
        AppLogger.warning('Failed to generate automatic safety backup: $e');
      }
    }

    final parsed = _parseContainer(fileContent);
    final derivedKeyBase64 = await _keyDerivation.derivePasswordKey(
      password: backupPassword,
      salt: manifest.salt,
      length: 32,
    );
    final derivedKeyBytes = base64Url.decode(derivedKeyBase64);
    final encKey = derivedKeyBytes.sublist(0, 16);

    final cipherBytes = base64Url.decode(parsed['payload']!);
    final decryptedBytes = _cryptStream(cipherBytes, encKey, base64Url.decode(manifest.salt));
    final rawJson = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
    final tablesMap = rawJson['tables'] as Map<String, dynamic>;

    final db = _databaseService.getActiveDatabase(currentProfileId);

    // Run initial integrity check
    final initialHealth = await db.rawQuery('PRAGMA integrity_check');
    AppLogger.info('Pre-restore database integrity: $initialHealth');

    int totalRestored = 0;
    final Map<String, int> restoredCounts = {};

    await db.transaction((txn) async {
      // Clear tables in reverse dependency order
      for (final table in _exportTables.reversed) {
        await txn.delete(table);
      }

      // Populate tables in forward order
      for (final table in _exportTables) {
        final rows = (tablesMap[table] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        for (final row in rows) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        restoredCounts[table] = rows.length;
        totalRestored += rows.length;
      }
    });

    // Run post-restore integrity check
    final postHealth = await db.rawQuery('PRAGMA integrity_check');
    final isHealthy = postHealth.isNotEmpty && postHealth.first['integrity_check'] == 'ok';

    if (!isHealthy) {
      throw BackupException('Database integrity check failed after restore: $postHealth');
    }

    AppLogger.info('Backup restore completed successfully. Total records: $totalRestored');
    return {
      'profileId': manifest.profileId,
      'profileName': manifest.profileName,
      'createdAt': manifest.createdAt.toIso8601String(),
      'totalRecords': totalRestored,
      'restoredCounts': restoredCounts,
      'safetyBackupPath': safetyBackupFile?.path,
    };
  }

  Map<String, String> _parseContainer(String fileContent) {
    final lines = fileContent.trim().split('\n');
    if (lines.isEmpty || lines[0].trim() != _containerHeader) {
      throw BackupException('Unrecognized or invalid Hisab Pro backup file header.');
    }

    final payloadIdx = lines.indexWhere((l) => l.trim() == _payloadDelimiter);
    final hmacIdx = lines.indexWhere((l) => l.trim() == _hmacDelimiter);

    if (payloadIdx == -1 || hmacIdx == -1 || payloadIdx >= hmacIdx) {
      throw BackupException('Corrupted backup file layout: missing section delimiters.');
    }

    final manifestPart = lines.sublist(1, payloadIdx).join('').trim();
    final payloadPart = lines.sublist(payloadIdx + 1, hmacIdx).join('').trim();
    final hmacPart = lines.sublist(hmacIdx + 1).join('').trim();

    return {
      'manifest': manifestPart,
      'payload': payloadPart,
      'hmac': hmacPart,
    };
  }

  /// Deterministic stream cipher combining SHA-256 blocks with Key, Salt, and Counter.
  Uint8List _cryptStream(Uint8List input, List<int> key, List<int> salt) {
    final output = Uint8List(input.length);
    int blockCounter = 0;
    int processed = 0;

    while (processed < input.length) {
      final counterBytes = ByteData(8)..setInt64(0, blockCounter, Endian.big);
      final blockKey = sha256.convert([
        ...key,
        ...salt,
        ...counterBytes.buffer.asUint8List(),
      ]).bytes;

      final blockSize = (input.length - processed) < blockKey.length
          ? (input.length - processed)
          : blockKey.length;

      for (int i = 0; i < blockSize; i++) {
        output[processed + i] = input[processed + i] ^ blockKey[i];
      }

      processed += blockSize;
      blockCounter++;
    }

    return output;
  }
}

