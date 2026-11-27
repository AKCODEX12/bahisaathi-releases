
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricSecurityService {
  BiometricSecurityService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static String _enabledKey(String role, String uid) {
    return 'biometric_enabled_${role}_$uid';
  }

  static String _setupKey(String role, String uid) {
    return 'biometric_setup_completed_${role}_$uid';
  }

  static String _customerAdminKey(String customerUid) {
    return 'biometric_customer_admin_$customerUid';
  }

  // Check whether this device supports local authentication.
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('DEVICE AUTH SUPPORT ERROR: $e');
      return false;
    }
  }

  // Check whether biometric/device authentication is enabled.
  static Future<bool> isEnabled({
    required String role,
    required String uid,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_enabledKey(role, uid)) ?? false;
  }

  // Check whether the user has already selected Enable or Skip.
  static Future<bool> isSetupCompleted({
    required String role,
    required String uid,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_setupKey(role, uid)) ?? false;
  }

  // Save Enable or Skip choice.
  static Future<void> saveSetupChoice({
    required String role,
    required String uid,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_enabledKey(role, uid), enabled);
    await prefs.setBool(_setupKey(role, uid), true);
  }

  // Authenticate using fingerprint, face, or device PIN/pattern.
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to open BahiSaathi',
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      );
    } catch (e) {
      debugPrint('BIOMETRIC AUTHENTICATION ERROR: $e');
      return false;
    }
  }

  // Verify authentication first, then enable the lock.
  static Future<bool> enableForAccount({
    required String role,
    required String uid,
  }) async {
    final supported = await isDeviceSupported();

    if (!supported) {
      return false;
    }

    final authenticated = await authenticate();

    if (!authenticated) {
      return false;
    }

    await saveSetupChoice(
      role: role,
      uid: uid,
      enabled: true,
    );

    return true;
  }

  // Save the Admin selected by a Customer.
  static Future<void> saveCustomerAdmin({
    required String customerUid,
    required String adminUid,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _customerAdminKey(customerUid),
      adminUid,
    );
  }

  // Get the previously selected Admin for a Customer.
  static Future<String?> getCustomerAdmin({
    required String customerUid,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_customerAdminKey(customerUid));
  }
}
