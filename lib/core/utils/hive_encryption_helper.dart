import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages a persistent 256-bit AES encryption key stored in the OS secure
/// keychain (Android Keystore / iOS Secure Enclave / Windows DPAPI).
///
/// The key is lazily generated on first launch and never stored in plaintext.
/// Use [getCipher] to get a [HiveAesCipher] suitable for [Hive.openBox].
class HiveEncryptionHelper {
  static const _storageKey = 'reminda_hive_aes_key';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  /// Returns a [HiveAesCipher] backed by a securely persisted 256-bit key.
  /// On first call the key is randomly generated and stored in the OS keychain.
  static Future<HiveAesCipher> getCipher() async {
    String? b64 = await _storage.read(key: _storageKey);
    if (b64 == null || b64.isEmpty) {
      final key = _generateKey();
      b64 = base64UrlEncode(key);
      await _storage.write(key: _storageKey, value: b64);
    }
    final keyBytes = base64Url.decode(b64);
    return HiveAesCipher(keyBytes);
  }

  /// Generates a cryptographically secure random 32-byte (256-bit) key.
  static Uint8List _generateKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }
}
