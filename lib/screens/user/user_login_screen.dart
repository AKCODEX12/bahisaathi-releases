
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'user_dashboard_screen.dart';
import '../admin/admin_login_screen.dart';
import '../../services/biometric_security_service.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool isResettingPassword = false;
  bool obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color _green = Color(0xFF16834A);
  static const Color _darkGreen = Color(0xFF10663A);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // USER / ADMIN SELECTOR
  // ----------------------------------------------------------

  Widget _roleButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 46,
        decoration: BoxDecoration(
          color: selected ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? [
            BoxShadow(
              color: _green.withOpacity(0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: selected ? null : onPressed,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    label == 'USER'
                        ? Icons.person_outline_rounded
                        : Icons.admin_panel_settings_outlined,
                    size: 19,
                    color: selected ? Colors.white : Colors.black54,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _switchToAdminLogin() {
    if (isLoading || isResettingPassword) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminLoginScreen(),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _green),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7FAF8),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE2EAE5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE2EAE5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _green, width: 1.7),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  // ----------------------------------------------------------
  // SHOW MESSAGE
  // ----------------------------------------------------------

  void _showMessage(
      String message, {
        Color backgroundColor = Colors.red,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ----------------------------------------------------------
  // CUSTOMER LOGIN
  // ----------------------------------------------------------

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    if (isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;

    User? loggedInUser;

    try {
      // STEP 1: Firebase Authentication Login

      final UserCredential credential =
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      loggedInUser = credential.user;

      if (loggedInUser == null) {
        throw FirebaseAuthException(
          code: 'login-failed',
          message: 'Unable to login.',
        );
      }

      // STEP 2: Check Global Gmail Role

      final roleSnapshot = await _firestore
          .collection('email_roles')
          .doc(email)
          .get();

      if (!roleSnapshot.exists) {
        await _auth.signOut();
        loggedInUser = null;

        _showMessage(
          'Please contact admin. This Gmail is not registered as a Customer.',
        );
        return;
      }

      final roleData = roleSnapshot.data();

      if (roleData == null) {
        await _auth.signOut();
        loggedInUser = null;

        _showMessage('Customer account information not found.');
        return;
      }

      final String role =
          roleData['role']?.toString().trim().toLowerCase() ?? '';

      final String registeredUid =
          roleData['uid']?.toString().trim() ?? '';

      // Admin Gmail must not be used for Customer Login.

      if (role != 'customer') {
        await _auth.signOut();
        loggedInUser = null;

        _showMessage(
          'This Gmail is registered as Admin. Please use Admin Login.',
        );
        return;
      }

      // STEP 3: Verify Firebase UID

      if (registeredUid != loggedInUser.uid) {
        await _auth.signOut();
        loggedInUser = null;

        _showMessage(
          'Customer account verification failed. Please contact support.',
        );
        return;
      }

      // STEP 4: Get Active Admin-Customer Relationships

      final relationshipSnapshot = await _firestore
          .collection('admin_customers')
          .where('customerUid', isEqualTo: loggedInUser.uid)
          .where('active', isEqualTo: true)
          .get();

      if (relationshipSnapshot.docs.isEmpty) {
        await _auth.signOut();
        loggedInUser = null;

        _showMessage(
          'Please contact admin. Your Customer access is inactive.',
        );
        return;
      }

      final List<String> adminUids = [];
      final Map<String, String> adminNames = {};

      for (final document in relationshipSnapshot.docs) {
        final data = document.data();

        final String adminUid =
            data['adminUid']?.toString().trim() ?? '';

        final String adminName =
            data['adminName']?.toString().trim() ?? '';

        if (adminUid.isNotEmpty && !adminUids.contains(adminUid)) {
          adminUids.add(adminUid);

          adminNames[adminUid] = adminName.isNotEmpty
              ? adminName
              : 'Admin name unavailable';
        }
      }

      if (adminUids.isEmpty) {
        await _auth.signOut();
        loggedInUser = null;

        _showMessage(
          'Customer account is not properly linked with an Admin.',
        );
        return;
      }

      // STEP 5: Select Admin If Multiple Relationships Exist

      String? selectedAdminUid;

      if (adminUids.length == 1) {
        selectedAdminUid = adminUids.first;
      } else {
        selectedAdminUid = await _selectAdmin(adminUids, adminNames);

        if (selectedAdminUid == null) {
          await _auth.signOut();
          loggedInUser = null;
          return;
        }
      }

      // STEP 6: Save Selected Admin UID For Future App Lock

      await BiometricSecurityService.saveCustomerAdmin(
        customerUid: loggedInUser.uid,
        adminUid: selectedAdminUid,
      );

      // STEP 7: Optional Biometric Setup On First Successful Login

      final setupCompleted =
      await BiometricSecurityService.isSetupCompleted(
        role: 'customer',
        uid: loggedInUser.uid,
      );

      if (!setupCompleted) {
        if (!mounted) return;

        final wantsBiometric = await _showBiometricSetupDialog();

        if (!mounted) return;

        if (wantsBiometric) {
          final enabled =
          await BiometricSecurityService.enableForAccount(
            role: 'customer',
            uid: loggedInUser.uid,
          );

          if (!enabled) {
            await BiometricSecurityService.saveSetupChoice(
              role: 'customer',
              uid: loggedInUser.uid,
              enabled: false,
            );

            if (mounted) {
              _showMessage(
                'Security setup was not completed. You can continue without it.',
                backgroundColor: Colors.orange,
              );
            }
          }
        } else {
          await BiometricSecurityService.saveSetupChoice(
            role: 'customer',
            uid: loggedInUser.uid,
            enabled: false,
          );
        }
      }

      // STEP 8: Open Original Customer Dashboard

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UserDashboardScreen(
            customerUid: loggedInUser!.uid,
            customerEmail: email,
            adminUid: selectedAdminUid!,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (loggedInUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {}
      }

      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No Firebase account exists for this Gmail.';
          break;

        case 'wrong-password':
          message = 'Wrong password.';
          break;

        case 'invalid-credential':
          message = 'Invalid Gmail or password.';
          break;

        case 'invalid-email':
          message = 'Invalid Gmail address.';
          break;

        case 'user-disabled':
          message = 'This Firebase account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;

        default:
          message = 'Login failed: ${e.message ?? e.code}';
      }

      _showMessage(message);
    } on FirebaseException catch (e) {
      if (loggedInUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {}
      }

      if (!mounted) return;

      String message;

      if (e.code == 'permission-denied') {
        message =
        'Firestore permission denied. New Firebase Rules are required.';
      } else if (e.code == 'unavailable') {
        message =
        'Firebase is temporarily unavailable. Check your internet.';
      } else {
        message = 'Firebase error: ${e.message ?? e.code}';
      }

      _showMessage(message);
    } catch (e) {
      if (loggedInUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {}
      }

      if (!mounted) return;

      _showMessage(
        'Login error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // SELECT ADMIN
  // ----------------------------------------------------------

  Future<String?> _selectAdmin(
      List<String> adminUids,
      Map<String, String> adminNames,
      ) async {
    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Select Admin Account',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: adminUids.length,
              separatorBuilder: (context, index) =>
              const Divider(height: 1),
              itemBuilder: (context, index) {
                final adminUid = adminUids[index];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5EC),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: _green,
                    ),
                  ),
                  title: Text(
                    adminNames[adminUid] ?? 'Admin name unavailable',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext, adminUid);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------
  // OPTIONAL BIOMETRIC SETUP
  // ----------------------------------------------------------

  Future<bool> _showBiometricSetupDialog() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Secure Your BahiSaathi App',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Would you like to protect your BahiSaathi account '
                'with Fingerprint, Face Unlock or your phone PIN/Pattern?\n\n'
                'You can also skip this option.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Skip'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.fingerprint),
              label: const Text('Enable Security'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ----------------------------------------------------------
  // SET PASSWORD / RESET PASSWORD
  // ----------------------------------------------------------

  Future<void> resetPassword() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage(
        'First enter your Gmail.',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (isResettingPassword) return;

    setState(() {
      isResettingPassword = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Password Link Sent',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'If an account exists with this Gmail, a password reset link '
                  'has been sent to:\n\n'
                  '$email\n\n'
                  'Open your Gmail and use the link to set your password.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No Firebase account exists for this Gmail yet.';
          break;

        case 'invalid-email':
          message = 'Invalid Gmail address.';
          break;

        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        default:
          message = 'Unable to send password link: ${e.message ?? e.code}';
      }

      _showMessage(message);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage('Firebase error: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;

      _showMessage('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isResettingPassword = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F4),
      appBar: AppBar(
        title: const Text(
          'User Login',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF183B28),
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // USER / ADMIN SELECTOR

                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: const Color(0xFFE4ECE6),
                        ),
                      ),
                      child: Row(
                        children: [
                          _roleButton(
                            label: 'USER',
                            selected: true,
                            onPressed: () {},
                          ),
                          const SizedBox(width: 5),
                          _roleButton(
                            label: 'ADMIN',
                            selected: false,
                            onPressed: _switchToAdminLogin,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // LOGIN CARD

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(0xFFE8EFEA),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF174D2D)
                                .withOpacity(0.07),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ICON

                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5EC),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 49,
                              color: _green,
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Welcome Back!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF193B28),
                            ),
                          ),

                          const SizedBox(height: 7),

                          const Text(
                            'Login to your BahiSaathi account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // EMAIL

                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: _inputDecoration(
                              label: 'Gmail',
                              hint: 'example@gmail.com',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';

                              if (email.isEmpty) {
                                return 'Enter your Gmail';
                              }

                              if (!email.contains('@') ||
                                  !email.contains('.')) {
                                return 'Enter a valid Gmail';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 19),

                          // PASSWORD

                          TextFormField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) {
                              if (!isLoading) {
                                login();
                              }
                            },
                            decoration: _inputDecoration(
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your password';
                              }

                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 7),

                          // RESET PASSWORD

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLoading || isResettingPassword
                                  ? null
                                  : resetPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: _green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 8,
                                ),
                              ),
                              child: isResettingPassword
                                  ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                'Set Password / Reset Password',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          // LOGIN BUTTON

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _green,
                                disabledBackgroundColor: _green,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: _green.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: isLoading
                                    ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Row(
                                  key: ValueKey('login'),
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 9),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 21,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 19),

                    // FOOTER

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Secure access to your BahiSaathi account',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
