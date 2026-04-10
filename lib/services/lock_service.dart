import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app PIN lock + biometrics.
///
/// PIN is stored in SharedPreferences under [_pinKey].
/// Biometrics are only attempted on Android 10+ (SDK 29+).
class LockService {
  LockService._();
  static final LockService instance = LockService._();

  static const _pinKey = 'app_lock_pin';
  static const _channel = MethodChannel('com.heyhappy.collabo/sdk_version');

  final _auth = LocalAuthentication();

  // ── PIN ──────────────────────────────────────────────────────────

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  Future<bool> checkPin(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    return stored != null && stored == input;
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }

  // ── Biometrics ───────────────────────────────────────────────────

  /// Returns true only on Android 10+ (SDK ≥ 29) with enrolled biometrics.
  Future<bool> isBiometricAvailable() async {
    if (!Platform.isAndroid) return false;
    final sdk = await _getSdkInt();
    if (sdk < 29) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Prompt biometric authentication. Returns true on success.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Déverrouillez Collabo',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Future<int> _getSdkInt() async {
    try {
      final int sdk = await _channel.invokeMethod('getSdkInt');
      return sdk;
    } catch (_) {
      // Fallback: assume modern Android
      return 29;
    }
  }
}
