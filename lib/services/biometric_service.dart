import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _keyEmail = 'biometric_email';
  static const String _keyPassword = 'biometric_password';
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
        persistAcrossBackgrounding: true,
        biometricOnly: false,
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
      await clearCredentials();
    }
  }

  Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: _keyEmail, value: email);
    await _secureStorage.write(key: _keyPassword, value: password);
  }

  Future<Map<String, String>?> getCredentials() async {
    final email = await _secureStorage.read(key: _keyEmail);
    final password = await _secureStorage.read(key: _keyPassword);
    
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _keyEmail);
    await _secureStorage.delete(key: _keyPassword);
  }
}
