
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_signup_screen.dart';
import '../user/user_login_screen.dart';
import 'widgets/admin_login_form.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  bool isLoading = false;
  bool isResettingPassword = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ================= ADMIN LOGIN =================

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    try {
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text.trim();

      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = credential.user;

      if (user == null) {
        throw Exception('Unable to login. Please try again.');
      }

      await user.reload();
      user = auth.currentUser;

      debugPrint('Email: ${user?.email}');
      debugPrint('Email Verified: ${user?.emailVerified}');

      if (user == null) {
        throw Exception('Unable to verify your account.');
      }

      if (!user.emailVerified) {
        await auth.signOut();

        showMessage(
          'Please verify your email before Admin Login.',
        );
        return;
      }

      final roleDoc = await firestore
          .collection('email_roles')
          .doc(email)
          .get();

      if (!roleDoc.exists) {
        await auth.signOut();

        showMessage(
          'Admin role not found. Please contact support.',
        );
        return;
      }

      final roleData = roleDoc.data();

      if (roleData == null ||
          roleData['role'] != 'admin' ||
          roleData['status'] != 'active' ||
          roleData['uid'] != user.uid ||
          roleData['email'] != email) {
        await auth.signOut();

        showMessage(
          'You do not have active Admin access.',
        );
        return;
      }

      final adminDoc = await firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) {
        await auth.signOut();

        showMessage(
          'Admin account not found. Please contact support.',
        );
        return;
      }

      final adminData = adminDoc.data();

      if (adminData == null ||
          adminData['role'] != 'admin' ||
          adminData['uid'] != user.uid ||
          (adminData['email'] as String?)
              ?.trim()
              .toLowerCase() !=
              email) {
        await auth.signOut();

        showMessage(
          'You do not have Admin access.',
        );
        return;
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminDashboardScreen(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('AUTH ERROR CODE: ${e.code}');
      debugPrint('AUTH ERROR MESSAGE: ${e.message}');

      await auth.signOut();

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'Account not found. Please check your email.';
          break;

        case 'wrong-password':
          message = 'Incorrect email or password.';
          break;

        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet.';
          break;

        default:
          message = 'Login failed. Please try again.';
      }

      showMessage(message);
    } on FirebaseException catch (e) {
      debugPrint('FIRESTORE ERROR CODE: ${e.code}');
      debugPrint('FIRESTORE ERROR MESSAGE: ${e.message}');

      await auth.signOut();

      showMessage(
        e.code == 'permission-denied'
            ? 'Permission denied. Please contact support.'
            : 'Something went wrong. Please try again.',
      );
    } catch (e) {
      debugPrint('ADMIN LOGIN ERROR: $e');

      await auth.signOut();

      showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ================= FORGOT PASSWORD =================

  Future<void> forgotPassword() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      showMessage('Please enter a valid email address first.');
      return;
    }

    setState(() {
      isResettingPassword = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      showMessage(
        'If an account exists with this email, a password reset link has been sent.',
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;

        default:
          message = 'Unable to send reset email. Please try again.';
      }

      showMessage(message);
    } catch (e) {
      showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isResettingPassword = false;
        });
      }
    }
  }

  // ================= OPEN ADMIN SIGNUP =================

  void openSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminSignupScreen(),
      ),
    );
  }

  // ================= SWITCH TO USER LOGIN =================

  void switchToUserLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const UserLoginScreen(),
      ),
    );
  }

  // ================= TOGGLE PASSWORD =================

  void togglePassword() {
    setState(() {
      obscurePassword = !obscurePassword;
    });
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return AdminLoginForm(
      formKey: _formKey,
      emailController: emailController,
      passwordController: passwordController,
      obscurePassword: obscurePassword,
      isLoading: isLoading,
      isResettingPassword: isResettingPassword,
      onLogin: login,
      onForgotPassword: forgotPassword,
      onSignup: openSignup,
      onTogglePassword: togglePassword,
      onSwitchToUser: switchToUserLogin,
    );
  }
}
