import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_user.dart';

class OfflineAuthService {
  static const _storage = FlutterSecureStorage();
  
  static const _keyUsername = 'cached_username';
  static const _keyPasswordHash = 'cached_password_hash';
  static const _keyPasswordSalt = 'cached_password_salt';
  static const _keyUserProfile = 'cached_user_profile';

  /// Hashes the given password with a randomly generated salt.
  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a secure random salt.
  static String _generateSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  /// Caches the user profile and credentials after a successful online login.
  static Future<void> cacheCredentials(String usernameOrEmail, String password, AppUser userProfile) async {
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    
    // Normalize username/email for matching later
    final normalizedUsername = usernameOrEmail.trim().toLowerCase();

    await _storage.write(key: _keyUsername, value: normalizedUsername);
    await _storage.write(key: _keyPasswordSalt, value: salt);
    await _storage.write(key: _keyPasswordHash, value: hash);
    await _storage.write(key: _keyUserProfile, value: json.encode(userProfile.toMap()));
  }

  /// Verifies credentials against the cached hash for offline login.
  static Future<AppUser?> verifyOffline(String usernameOrEmail, String password) async {
    final cachedUsername = await _storage.read(key: _keyUsername);
    final cachedSalt = await _storage.read(key: _keyPasswordSalt);
    final cachedHash = await _storage.read(key: _keyPasswordHash);

    if (cachedUsername == null || cachedSalt == null || cachedHash == null) {
      return null; // No cached credentials
    }

    final normalizedInput = usernameOrEmail.trim().toLowerCase();
    
    // We do a simple case-insensitive check against whatever was typed
    if (normalizedInput != cachedUsername) {
      return null;
    }

    final inputHash = _hashPassword(password, cachedSalt);
    if (inputHash == cachedHash) {
      return await getCachedProfile();
    }

    return null;
  }

  /// Retrieves the last cached user profile (used for splash screen offline restore).
  static Future<AppUser?> getCachedProfile() async {
    final profileJson = await _storage.read(key: _keyUserProfile);
    if (profileJson != null) {
      try {
        final map = json.decode(profileJson);
        return AppUser.fromMap(map);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Clears the credential cache (e.g., on explicit logout).
  static Future<void> clearCache() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPasswordHash);
    await _storage.delete(key: _keyPasswordSalt);
    await _storage.delete(key: _keyUserProfile);
  }
}
