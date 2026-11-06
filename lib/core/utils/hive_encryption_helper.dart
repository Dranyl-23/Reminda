import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Manages a persistent 256-bit AES encryption key stored in the OS secure
/// keychain (Android Keystore / iOS Secure Enclave / Windows DPAPI).
///
/// The key is lazily generated on first launch and never stored in plaintext.
/// Use [getCipher] to get a [HiveAesCipher] suitable for [Hive.openBox], or
/// [openSecureBox] to open a box with safe migration / recovery handling.
class HiveEncryptionHelper {
  static const _storageKey = 'reminda_hive_aes_key';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  /// Returns a [HiveAesCipher] backed by a securely persisted 256-bit key.
  /// On first call the key is randomly generated and stored in the OS keychain.
  /// If secure storage fails or is unavailable on the platform, returns null.
  static Future<HiveAesCipher?> getCipher() async {
    try {
      String? b64 = await _storage.read(key: _storageKey);
      if (b64 == null || b64.isEmpty) {
        final key = _generateKey();
        b64 = base64UrlEncode(key);
        await _storage.write(key: _storageKey, value: b64);
      }
      final keyBytes = base64Url.decode(b64);
      return HiveAesCipher(keyBytes);
    } catch (_) {
      return null;
    }
  }

  /// Opens (or creates) a `Box<String>` encrypted with the keychain-backed key,
  /// without ever risking silent data loss.
  ///
  /// Hive's default `crashRecovery: true` silently TRUNCATES a box when the key
  /// is wrong or the file can't be decoded, so every "probing" open below uses
  /// `crashRecovery: false` (throws instead of modifying the file).
  ///
  /// Order of attempts:
  ///  1. Strict open with the cipher (normal path).
  ///  2. Back up the box file, then strict open as plaintext. If that works the
  ///     box is a legacy unencrypted box, so it is migrated into an encrypted one.
  ///  3. Recovering open with the cipher (the original file is already backed up).
  /// If no cipher is available (secure storage unsupported) a plain box is used.
  static Future<Box<String>> openSecureBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);

    final cipher = await getCipher();

    if (cipher == null) {
      // No secure key available on this platform / right now.
      await _backupBoxFile(boxName);
      return Hive.openBox<String>(boxName);
    }

    // 1. Normal path: strict encrypted open.
    try {
      return await Hive.openBox<String>(
        boxName,
        encryptionCipher: cipher,
        crashRecovery: false,
      );
    } catch (e) {
      debugPrint('HiveEncryptionHelper[$boxName]: strict encrypted open failed ($e)');
    }

    // Preserve the original bytes before trying anything else.
    await _backupBoxFile(boxName);

    // 2. Legacy unencrypted box -> migrate into an encrypted box.
    try {
      final plain = await Hive.openBox<String>(boxName, crashRecovery: false);
      final data = <String, String>{
        for (final entry in plain.toMap().entries)
          entry.key.toString(): entry.value,
      };
      await plain.deleteFromDisk();
      final encrypted = await Hive.openBox<String>(
        boxName,
        encryptionCipher: cipher,
      );
      if (data.isNotEmpty) await encrypted.putAll(data);
      debugPrint(
        'HiveEncryptionHelper[$boxName]: migrated ${data.length} entries to encrypted box',
      );
      return encrypted;
    } catch (e) {
      debugPrint('HiveEncryptionHelper[$boxName]: plain/migration open failed ($e)');
      if (Hive.isBoxOpen(boxName)) {
        try {
          await Hive.box<String>(boxName).close();
        } catch (_) {}
      }
    }

    // 3. Last resort: recovering encrypted open. A backup of the original
    //    file already exists next to the box ("<name>.hive.bak").
    debugPrint(
      'HiveEncryptionHelper[$boxName]: falling back to recovering encrypted open',
    );
    return Hive.openBox<String>(boxName, encryptionCipher: cipher);
  }

  /// Copies `<box>.hive` to `<box>.hive.bak` (only if no backup exists yet, so the
  /// oldest intact copy is never overwritten by a later corrupted one).
  static Future<void> _backupBoxFile(String boxName) async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final source = File('${dir.path}${Platform.pathSeparator}${boxName.toLowerCase()}.hive');
      if (!await source.exists() || await source.length() == 0) return;
      final backup = File('${source.path}.bak');
      if (await backup.exists()) return;
      await source.copy(backup.path);
      debugPrint('HiveEncryptionHelper[$boxName]: backed up box to ${backup.path}');
    } catch (e) {
      debugPrint('HiveEncryptionHelper[$boxName]: backup skipped ($e)');
    }
  }

  /// Generates a cryptographically secure random 32-byte (256-bit) key.
  static Uint8List _generateKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }
}
