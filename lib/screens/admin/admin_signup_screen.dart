
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/biometric_security_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';
import 'widgets/admin_signup_form.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool rememberPassword = false;

  // ================= SIGNUP =================

  Future<void> signup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage('Please fill all fields');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      showMessage('Please enter a valid email');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must be at least 6 characters');
      return;
    }

    if (!rememberPassword) {
      showMessage(
        'Please tick "Remember password" before creating your account',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    User? newUser;
    bool roleReserved = false;

    try {
      // Create Firebase Authentication account.
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      newUser = credential.user;

      if (newUser == null) {
        throw Exception('Account could not be created');
      }

      // Reserve this Gmail as Admin.
      // Existing Customer/Admin role must never be overwritten.
      final roleRef = FirebaseFirestore.instance
          .collection('email_roles')
          .doc(email);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final roleSnapshot = await transaction.get(roleRef);

        if (roleSnapshot.exists) {
          throw Exception(
            'This Gmail is already registered with another role. '
                'Please use a different Gmail.',
          );
        }

        transaction.set(roleRef, {
          'email': email,
          'uid': newUser!.uid,
          'role': 'admin',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      roleReserved = true;

      // Send email verification link.
      try {
        await newUser.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        debugPrint('VERIFICATION EMAIL ERROR: ${e.message}');
      }

      if (!mounted) return;

      // Show the original verification popup.
      showVerificationDialog(newUser, name, email);
    } on FirebaseAuthException catch (e) {
      debugPrint('AUTH ERROR CODE: ${e.code}');
      debugPrint('AUTH ERROR MESSAGE: ${e.message}');

      if (!mounted) return;

      if (e.code == 'email-already-in-use') {
        showAlreadyExistsDialog();
      } else if (e.code == 'weak-password') {
        showMessage(
          'Password is too weak. Use at least 6 characters.',
        );
      } else if (e.code == 'invalid-email') {
        showMessage('Please enter a valid email');
      } else if (e.code == 'operation-not-allowed') {
        showMessage(
          'Email/Password authentication is not enabled.',
        );
      } else {
        showMessage(e.message ?? 'Signup failed');
      }
    } catch (e) {
      debugPrint('ADMIN SIGNUP ERROR: $e');

      // If role reservation failed, remove only the Auth account
      // created by this signup attempt.
      if (newUser != null && !roleReserved) {
        try {
          await newUser.delete();
        } catch (deleteError) {
          debugPrint('AUTH CLEANUP ERROR: $deleteError');
        }

        try {
          await FirebaseAuth.instance.signOut();
        } catch (signOutError) {
          debugPrint('SIGNOUT ERROR: $signOutError');
        }
      }

      if (!mounted) return;

      showMessage('Signup failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ================= EMAIL VERIFICATION DIALOG =================

  void showVerificationDialog(
      User user,
      String name,
      String email,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Verify Your Email',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'A verification link has been sent to:\n\n'
                '$email\n\n'
                'Please open your Gmail and click the Verify Email link. '
                'After verification, return to this app and tap '
                '"I have verified".',
          ),
          actions: [
            // Resend verification email.
            TextButton(
              onPressed: loading
                  ? null
                  : () async {
                try {
                  await user.sendEmailVerification();

                  if (!mounted) return;

                  showMessage(
                    'Verification email sent again',
                  );
                } on FirebaseAuthException catch (e) {
                  if (!mounted) return;

                  showMessage(
                    e.message ?? 'Could not resend email',
                  );
                } catch (e) {
                  if (!mounted) return;

                  showMessage(
                    'Could not resend email: $e',
                  );
                }
              },
              child: const Text('Resend Email'),
            ),

            // Verify email button.
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () {
                verifyEmailAndContinue(
                  user,
                  name,
                  email,
                  dialogContext,
                );
              },
              child: const Text("I've Verified"),
            ),
          ],
        );
      },
    );
  }

  // ================= VERIFY EMAIL AND CREATE ACCOUNT =================

  Future<void> verifyEmailAndContinue(
      User user,
      String name,
      String email,
      BuildContext dialogContext,
      ) async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      // Refresh Firebase user information.
      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        throw Exception('Please login again');
      }

      if (!refreshedUser.emailVerified) {
        if (mounted) {
          showMessage(
            'Email is not verified yet. Please check your Gmail.',
          );
        }
        return;
      }

      if (refreshedUser.email?.toLowerCase() != email) {
        throw Exception('Logged-in Gmail does not match signup Gmail.');
      }

      // Refresh ID token so Firestore Rules can see email_verified=true.
      await refreshedUser.getIdToken(true);

      final firestore = FirebaseFirestore.instance;

      final roleRef = firestore
          .collection('email_roles')
          .doc(email);

      final adminRef = firestore
          .collection('admins')
          .doc(refreshedUser.uid);

      // Activate the reserved Admin role and create Admin profile
      // together in one Firestore transaction.
      await firestore.runTransaction((transaction) async {
        final roleSnapshot = await transaction.get(roleRef);
        final adminSnapshot = await transaction.get(adminRef);

        if (!roleSnapshot.exists) {
          throw Exception('Admin role reservation was not found.');
        }

        final roleData = roleSnapshot.data();

        if (roleData == null ||
            roleData['uid'] != refreshedUser.uid ||
            roleData['email'] != email ||
            roleData['role'] != 'admin' ||
            roleData['status'] != 'pending') {
          throw Exception(
            'Admin role verification failed. Please contact support.',
          );
        }

        if (adminSnapshot.exists) {
          throw Exception('Admin profile already exists.');
        }

        transaction.update(roleRef, {
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(adminRef, {
          'uid': refreshedUser.uid,
          'name': name,
          'email': email,
          'role': 'admin',
          'emailVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      // Close verification popup only after successful Firestore writes.
      Navigator.pop(dialogContext);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account Created Successfully!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Let the success message appear before Dashboard.
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Optional biometric setup after successful Admin signup.
      final wantsBiometric = await showBiometricSetupDialog();

      if (!mounted) return;

      if (wantsBiometric) {
        final enabled = await BiometricSecurityService.enableForAccount(
          role: 'admin',
          uid: refreshedUser.uid,
        );

        if (!enabled) {
          await BiometricSecurityService.saveSetupChoice(
            role: 'admin',
            uid: refreshedUser.uid,
            enabled: false,
          );

          if (mounted) {
            showMessage(
              'Security setup was not completed. You can continue without it.',
            );
          }
        }
      } else {
        // User selected Skip.
        await BiometricSecurityService.saveSetupChoice(
          role: 'admin',
          uid: refreshedUser.uid,
          enabled: false,
        );
      }

      if (!mounted) return;

      // Open the original Admin Dashboard.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminDashboardScreen(),
        ),
            (route) => false,
      );
    } catch (e) {
      debugPrint('ADMIN VERIFICATION ERROR: $e');

      if (mounted) {
        showMessage('Account creation failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ================= OPTIONAL BIOMETRIC SETUP =================

  Future<bool> showBiometricSetupDialog() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Secure Your BahiSaathi App',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
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

  // ================= ACCOUNT ALREADY EXISTS =================

  void showAlreadyExistsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Account Already Exists',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'An account with this Gmail already exists.\n\n'
                'Please login with your existing account.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminLoginScreen(),
                  ),
                );
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  // ================= LOGIN NAVIGATION =================

  void openLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminLoginScreen(),
      ),
    );
  }

  // ================= MESSAGE =================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ================= DISPOSE =================

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Signup'),
      ),
      body: AdminSignupForm(
        nameController: nameController,
        emailController: emailController,
        passwordController: passwordController,
        loading: loading,
        obscurePassword: obscurePassword,
        rememberPassword: rememberPassword,

        onTogglePassword: () {
          setState(() {
            obscurePassword = !obscurePassword;
          });
        },

        onRememberChanged: (value) {
          setState(() {
            rememberPassword = value;
          });
        },

        onSignup: signup,
        onLogin: openLogin,
      ),
    );
  }
}
