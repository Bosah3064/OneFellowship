import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _prefKeyBiometricEnabled = 'onefellowship_biometric_enabled';

  /// Check if biometric hardware exists and is supported
  static Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get list of available biometric types (e.g. fingerprint, face)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Get available biometrics error: $e');
      return [];
    }
  }

  /// Check if user has enabled biometric unlock in settings
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true if hardware is available, otherwise false
    return prefs.getBool(_prefKeyBiometricEnabled) ?? false;
  }

  /// Toggle biometric unlock preference
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyBiometricEnabled, enabled);
  }

  /// Prompt user to authenticate via fingerprint / face
  static Future<bool> authenticate({
    String reason = 'Scan fingerprint or use biometrics to unlock OneFellowship',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authenticate error: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric unexpected error: $e');
      return false;
    }
  }
}

