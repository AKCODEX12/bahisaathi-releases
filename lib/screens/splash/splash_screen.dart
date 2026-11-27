import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../firebase_options.dart';
import '../../services/biometric_security_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../user/user_dashboard_screen.dart';
import '../user/user_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
bool _checking = true;
bool _showLockScreen = false;
bool _navigated = false;
bool _startupStarted = false;
bool _nativeSplashRemoved = false;

String _message = 'Please wait...';

late AnimationController _entryController;
late Animation<double> _logoBreath;
late Animation<double> _bottomFade;
late Animation<Offset> _bottomSlide;
late AnimationController _pulseController;
late AnimationController _exitController;

@override
void initState() {
  super.initState();

  // ✅ Frame render hone ka wait kiye bina turant Native Splash hatayein
  _removeNativeSplash();

  _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  _logoBreath = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.07), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.07, end: 1.0), weight: 50),
  ]).animate(CurvedAnimation(
    parent: _entryController,
    curve: Curves.easeInOut,
  ));

  _bottomFade = CurvedAnimation(
    parent: _entryController,
    curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
  );

  _bottomSlide = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _entryController,
    curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
  ));

  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..repeat();

  _exitController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _startupStarted) return;

    _entryController.forward();
    _startupStarted = true;
    _checkStartup();
  });
}

@override
void dispose() {
_entryController.dispose();
_pulseController.dispose();
_exitController.dispose();
super.dispose();
}

void _removeNativeSplash() {
if (_nativeSplashRemoved) return;

_nativeSplashRemoved = true;
FlutterNativeSplash.remove();
}

Future<void> _checkStartup() async {
if (!mounted || _navigated) return;

setState(() {
_checking = true;
_showLockScreen = false;
_message = 'Please wait...';
});

final minAnimationTimer = Future.delayed(const Duration(milliseconds: 1100));

try {
if (Firebase.apps.isEmpty) {
await Firebase.initializeApp(
options: DefaultFirebaseOptions.currentPlatform,
);
}

final auth = FirebaseAuth.instance;
final firestore = FirebaseFirestore.instance;

final user = auth.currentUser;

if (user == null) {
await minAnimationTimer;
await _openUserLogin();
return;
}

final uid = user.uid;
final email = user.email?.trim().toLowerCase();

if (email == null || email.isEmpty) {
await auth.signOut();
await minAnimationTimer;
await _openUserLogin();
return;
}

final roleDoc = await firestore
.collection('email_roles')
.doc(email)
.get();

if (!roleDoc.exists) {
await auth.signOut();
await minAnimationTimer;
await _openUserLogin();
return;
}

final roleData = roleDoc.data();

if (roleData == null ||
roleData['uid'] != uid ||
roleData['status'] != 'active' ||
roleData['email'] is! String ||
(roleData['email'] as String).trim().toLowerCase() != email) {
await auth.signOut();
await minAnimationTimer;
await _openUserLogin();
return;
}

final role = roleData['role'] as String?;

if (role != 'admin' && role != 'customer') {
await auth.signOut();
await minAnimationTimer;
await _openUserLogin();
return;
}

String? customerAdminUid;

if (role == 'admin') {
final adminDoc = await firestore
.collection('admins')
.doc(uid)
.get();

final adminData = adminDoc.data();

if (!adminDoc.exists ||
adminData == null ||
adminData['uid'] != uid ||
adminData['role'] != 'admin' ||
adminData['email'] is! String ||
(adminData['email'] as String).trim().toLowerCase() != email) {
await auth.signOut();
await minAnimationTimer;
await _openUserLogin();
return;
}
} else {
customerAdminUid =
await BiometricSecurityService.getCustomerAdmin(
customerUid: uid,
);

if (customerAdminUid == null ||
customerAdminUid.trim().isEmpty) {
await auth.signOut();
await minAnimationTimer;
await _openUserLogin();
return;
}

final relationship = await firestore
.collection('admin_customers')
.where('customerUid', isEqualTo: uid)
.where('adminUid', isEqualTo: customerAdminUid)
.where('active', isEqualTo: true)
.limit(1)
.get();

if (relationship.docs.isEmpty) {
await auth.signOut();
await minAnimationTimer;
await _openUserLogin();
return;
}
}

final biometricEnabled =
await BiometricSecurityService.isEnabled(
role: role!,
uid: uid,
);

if (!mounted || _navigated) return;

if (biometricEnabled) {
_removeNativeSplash();

setState(() {
_showLockScreen = true;
_checking = true;
_message = 'Authenticate to open BahiSaathi';
});

final authenticated =
await BiometricSecurityService.authenticate();

if (!mounted || _navigated) return;

if (!authenticated) {
await _showLockedMessage(
'Authentication was not completed. Please try again.',
);
return;
}
}

await minAnimationTimer;
if (role == 'admin') {
await _openAdminDashboard();
} else {
await _openCustomerDashboard(
uid: uid,
email: email,
adminUid: customerAdminUid!,
);
}
} catch (e) {
debugPrint('STARTUP ERROR: $e');

await _showLockedMessage(
'Unable to verify your account. Check your internet and try again.',
);
}
}
Route _smoothFadeRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

Future<void> _openAdminDashboard() async {
  if (!mounted || _navigated) return;

  _removeNativeSplash();
  _navigated = true;

  if (!_showLockScreen) {
    await _exitController.forward();
    if (!mounted) return;
  }

  Navigator.pushAndRemoveUntil(
    context,
    _smoothFadeRoute(const AdminDashboardScreen()),
        (route) => false,
  );
}

Future<void> _openCustomerDashboard({
  required String uid,
  required String email,
  required String adminUid,
}) async {
  if (!mounted || _navigated) return;

  _removeNativeSplash();
  _navigated = true;

  if (!_showLockScreen) {
    await _exitController.forward();
    if (!mounted) return;
  }

  Navigator.pushAndRemoveUntil(
    context,
    _smoothFadeRoute(
      UserDashboardScreen(
        customerUid: uid,
        customerEmail: email,
        adminUid: adminUid,
      ),
    ),
        (route) => false,
  );
}

Future<void> _openUserLogin() async {
  if (!mounted || _navigated) return;

  _removeNativeSplash();
  _navigated = true;

  if (!_showLockScreen) {
    await _exitController.forward();
    if (!mounted) return;
  }

  Navigator.pushReplacement(
    context,
    _smoothFadeRoute(const UserLoginScreen()),
  );
}

Future<void> _showLockedMessage(String message) async {
  if (!mounted) return;

  _removeNativeSplash();

  setState(() {
    _checking = false;
    _showLockScreen = true;
    _message = message;
  });
}

Future<void> _logout() async {
  try {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    await _openUserLogin();
  } catch (e) {
    debugPrint('BIOMETRIC LOGOUT ERROR: $e');

    await _showLockedMessage(
      'Unable to logout. Please try again.',
    );
  }
}

Widget _buildAnimatedSplash() {
  return Scaffold(
    backgroundColor: Colors.white,
    body: AnimatedBuilder(
      animation: Listenable.merge([
        _entryController,
        _pulseController,
        _exitController,
      ]),
      builder: (context, child) {
        double exitScale = 1.0 + (_exitController.value * 0.16);
        double exitOpacity = (1.0 - _exitController.value).clamp(0.0, 1.0);

        return Opacity(
          opacity: exitOpacity,
          child: Transform.scale(
            scale: exitScale,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: 0.78 + (_pulseController.value * 0.55),
                          child: Container(
                            width: 155,
                            height: 155,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(34),
                              border: Border.all(
                                color: const Color(0xFFF5B400).withOpacity(
                                  (1.0 - _pulseController.value) * 0.60,
                                ),
                                width: 2.0,
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.82 + (_pulseController.value * 0.45),
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(34),
                              color: const Color(0xFF0B5318).withOpacity(
                                (1.0 - _pulseController.value) * 0.10,
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _logoBreath.value,
                          child: Image.asset(
                            'assets/images/bahisaathi_logo_cropped.png',
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 70,
                  child: FadeTransition(
                    opacity: _bottomFade,
                    child: SlideTransition(
                      position: _bottomSlide,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'BahiSaathi',
                            style: TextStyle(
                              color: Color(0xFF1B1B1B),
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                size: 15,
                                color: Color(0xFF0B5318),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'लेनदार और कर्जदार का पक्का हिसाब',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildLockScreen() {
  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 75,
                color: Colors.green,
              ),
              const SizedBox(height: 18),
              const Text(
                'BahiSaathi Locked',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 28),
              if (_checking)
                const CircularProgressIndicator(color: Colors.green)
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checkStartup,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock / Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  if (_showLockScreen) {
    return _buildLockScreen();
  }
  return _buildAnimatedSplash();
}
}
