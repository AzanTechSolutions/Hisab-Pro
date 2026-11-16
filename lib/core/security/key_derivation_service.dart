import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cryptographically secure, pure Dart key derivation service.
/// Uses standard PBKDF2 with HMAC-SHA256 (RFC 2898 / NIST SP 800-132 compliant).
/// Requires zero native FFI binaries or dynamic libraries (.so), ensuring 100% stability
/// across all Android devices (arm64-v8a, armeabi-v7a, x86_64), iOS, and Web.
class KeyDerivationService {
  const KeyDerivationService();

  String buildSalt([int length = 16]) {
    final random = Random.secure();
    final randomBytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(randomBytes);
  }

  /// Derives a 256-bit (or specified length) encryption key from [password] and [salt].
  Future<String> derivePasswordKey({
    required String password,
    required String salt,
    int memory = 0,
    int iterations = 10000,
    int parallelism = 1,
    int length = 32,
  }) async {
    final passwordBytes = utf8.encode(password);
    final saltBytes = base64Url.decode(salt);
    final derived = _pbkdf2HmacSha256(
      password: passwordBytes,
      salt: saltBytes,
      iterations: iterations > 0 ? iterations : 10000,
      keyLength: length,
    );
    return base64UrlEncode(derived);
  }

  /// RFC 2898 PBKDF2 implementation using HMAC-SHA256.
  static Uint8List _pbkdf2HmacSha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final numBlocks = (keyLength + 31) ~/ 32;
    final result = BytesBuilder(copy: false);

    for (int blockIndex = 1; blockIndex <= numBlocks; blockIndex++) {
      // U_1 = PRF(password, salt || INT_32_BE(blockIndex))
      final blockBytes = [
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ];
      final saltWithBlock = List<int>.from(salt)..addAll(blockBytes);
      var u = hmac.convert(saltWithBlock).bytes;
      final xorSum = List<int>.from(u);

      for (int iter = 1; iter < iterations; iter++) {
        u = hmac.convert(u).bytes;
        for (int k = 0; k < 32; k++) {
          xorSum[k] ^= u[k];
        }
      }

      result.add(xorSum);
    }

    return Uint8List.fromList(result.takeBytes().sublist(0, keyLength));
  }
}
