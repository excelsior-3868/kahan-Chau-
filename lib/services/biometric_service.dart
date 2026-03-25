import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _keyToken = 'biometric_token_v2'; // New key for token
  static const String _keyEnabled = 'biometric_enabled';

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to log in',
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    if (!value) {
      await clearToken();
    }
  }

  Future<void> saveToken(String refreshToken) async {
    await _secureStorage.write(key: _keyToken, value: refreshToken);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _keyToken);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _keyToken);
  }
}
