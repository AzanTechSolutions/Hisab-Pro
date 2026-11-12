import 'dart:convert';
import 'dart:math';

import 'package:serverpod_argon2/serverpod_argon2.dart';

class KeyDerivationService {
  const KeyDerivationService();

  String buildSalt() {
    final random = Random.secure();
    final randomBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(randomBytes);
  }

  Future<String> derivePasswordKey({
    required String password,
    required String salt,
    int memory = 64 * 1024,
    int iterations = 3,
    int parallelism = 1,
    int length = 32,
  }) async {
    final argon2 = await Argon2.load();
    final result = argon2.deriveKey(
      password: utf8.encode(password),
      salt: base64Url.decode(salt),
      parameters: Argon2Parameters(
        iterations: iterations,
        memoryKiB: memory,
        parallelism: parallelism,
        hashLength: length,
      ),
    );
    return base64UrlEncode(result);
  }
}
