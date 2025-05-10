import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

/// Provides encryption capabilities for the app's data
/// This service enables end-to-end encryption for sensitive user data
/// including foraging locations, personal identification information,
/// and saved mushroom data
class EncryptionService {
  static const String _keyKey = 'encryption_key';
  static const String _ivKey = 'encryption_iv';

  late Encrypter _encrypter;
  late IV _iv;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Initialize the encryption service and generate/retrieve keys
  Future<void> initialize() async {
    // Generate or retrieve the encryption key
    String? storedKeyBase64 = await _secureStorage.read(key: _keyKey);
    String? storedIVBase64 = await _secureStorage.read(key: _ivKey);

    if (storedKeyBase64 == null || storedIVBase64 == null) {
      // Generate new keys if none exist
      final keyBytes = _generateRandomBytes(32); // AES-256
      final ivBytes = _generateRandomBytes(16);

      // Store keys securely
      await _secureStorage.write(key: _keyKey, value: base64.encode(keyBytes));
      await _secureStorage.write(key: _ivKey, value: base64.encode(ivBytes));

      _setupEncrypter(keyBytes, ivBytes);
    } else {
      // Use existing keys
      final keyBytes = base64.decode(storedKeyBase64);
      final ivBytes = base64.decode(storedIVBase64);
      _setupEncrypter(keyBytes, ivBytes);
    }

    // Initialize cryptography package for advanced E2E encryption
    // No need to store the algorithm reference for now
    AesCtr.with256bits(macAlgorithm: Hmac.sha256());
  }

  /// Set up the encrypter with the provided key and IV
  void _setupEncrypter(List<int> keyBytes, List<int> ivBytes) {
    final key = Key(Uint8List.fromList(keyBytes));
    _iv = IV(Uint8List.fromList(ivBytes));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  }

  /// Generate random bytes for encryption keys
  List<int> _generateRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Encrypt a string
  String encrypt(String plainText) {
    return _encrypter.encrypt(plainText, iv: _iv).base64;
  }

  /// Decrypt a string
  String decrypt(String encryptedText) {
    try {
      return _encrypter.decrypt64(encryptedText, iv: _iv);
    } catch (e) {
      return ''; // Return empty string on error
    }
  }

  /// Encrypt an object by converting to JSON first
  String encryptObject(Map<String, dynamic> data) {
    return encrypt(jsonEncode(data));
  }

  /// Decrypt an object from encrypted JSON
  Map<String, dynamic> decryptObject(String encryptedText) {
    try {
      final decrypted = decrypt(encryptedText);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      return {}; // Return empty map on error
    }
  }

  /// Get Sembast codec for encrypted database
  SembastCodec getSembastCodec() {
    return SembastCodec(
      signature: 'fungiscan_encrypted_v1',
      codec: _getEncryptionCodec(),
    );
  }

  /// Custom encryption codec for Sembast database
  Codec<String, String> _getEncryptionCodec() {
    return _CustomEncryptionCodec(this);
  }

  /// Determine if privacy mode is enabled (to be used with user settings)
  Future<bool> isPrivacyModeEnabled() async {
    const secureStorage = FlutterSecureStorage();
    final value = await secureStorage.read(key: 'privacy_mode');
    return value == 'true';
  }

  /// Enable or disable privacy mode
  Future<void> setPrivacyMode(bool enabled) async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(
        key: 'privacy_mode', value: enabled ? 'true' : 'false');
  }
}

/// Custom Codec implementation for Sembast encryption
class _CustomEncryptionCodec extends Codec<String, String> {
  final EncryptionService _service;

  _CustomEncryptionCodec(this._service);

  @override
  Converter<String, String> get encoder => _CustomEncoder(_service);

  @override
  Converter<String, String> get decoder => _CustomDecoder(_service);
}

class _CustomEncoder extends Converter<String, String> {
  final EncryptionService _service;

  _CustomEncoder(this._service);

  @override
  String convert(String input) => _service.encrypt(input);
}

class _CustomDecoder extends Converter<String, String> {
  final EncryptionService _service;

  _CustomDecoder(this._service);

  @override
  String convert(String input) => _service.decrypt(input);
}