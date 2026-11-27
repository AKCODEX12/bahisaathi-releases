
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../../firebase_options.dart';

class CustomerCreationResult {
  final bool success;
  final String message;
  final bool passwordResetEmailSent;

  const CustomerCreationResult({
    required this.success,
    required this.message,
    this.passwordResetEmailSent = false,
  });
}

class CustomerService {
  CustomerService._();

  static final CustomerService _instance = CustomerService._();

  factory CustomerService() => _instance;

  static const String _customerAppName = 'customerAuth';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<FirebaseAuth> _getCustomerAuth() async {
    FirebaseApp customerApp;

    try {
      customerApp = Firebase.app(_customerAppName);
    } catch (_) {
      customerApp = await Firebase.initializeApp(
        name: _customerAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    return FirebaseAuth.instanceFor(app: customerApp);
  }

  String _generateTemporaryPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';

    final random = Random.secure();

    return List.generate(
      16,
          (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<CustomerCreationResult> addCustomer({
    required String adminUid,
    required String name,
    String optionalName = '',
    required String email,
    String mobile = '',
    String address = '',
    String description = '',
    String depositType = 'bearing',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanDepositType = depositType.trim().toLowerCase();

    if (adminUid.trim().isEmpty) {
      return const CustomerCreationResult(
        success: false,
        message: 'Admin login not found. Please login again.',
      );
    }

    if (cleanName.isEmpty) {
      return const CustomerCreationResult(
        success: false,
        message: 'Please enter customer name.',
      );
    }

    if (!_isValidEmail(normalizedEmail)) {
      return const CustomerCreationResult(
        success: false,
        message: 'Please enter a valid email address.',
      );
    }

    if (!['bearing', 'interest'].contains(cleanDepositType)) {
      return const CustomerCreationResult(
        success: false,
        message: 'Please select a valid Deposit Type.',
      );
    }

    FirebaseAuth? customerAuth;
    User? newlyCreatedUser;

    try {
      final adminSnapshot = await _firestore
          .collection('admins')
          .doc(adminUid.trim())
          .get();

      final adminName =
          adminSnapshot.data()?['name']?.toString().trim() ?? '';

      customerAuth = await _getCustomerAuth();

      final emailRoleRef =
      _firestore.collection('email_roles').doc(normalizedEmail);

      final existingRole = await emailRoleRef.get();

      String customerUid;
      bool isNewCustomerAccount = false;

      if (existingRole.exists) {
        final roleData = existingRole.data();

        if (roleData == null) {
          return const CustomerCreationResult(
            success: false,
            message: 'Customer role information is incomplete.',
          );
        }

        final existingRoleName =
        roleData['role']?.toString().trim().toLowerCase();

        if (existingRoleName == 'admin') {
          return const CustomerCreationResult(
            success: false,
            message:
            'This Gmail is already registered as Admin. It cannot be added as a Customer.',
          );
        }

        if (existingRoleName != 'customer') {
          return const CustomerCreationResult(
            success: false,
            message: 'This Gmail has an invalid account role.',
          );
        }

        customerUid = roleData['uid']?.toString() ?? '';

        if (customerUid.isEmpty) {
          return const CustomerCreationResult(
            success: false,
            message:
            'Customer account UID is missing. Please contact support.',
          );
        }
      } else {
        try {
          final credential =
          await customerAuth.createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: _generateTemporaryPassword(),
          );

          newlyCreatedUser = credential.user;

          if (newlyCreatedUser == null) {
            throw Exception('Firebase did not return a Customer account.');
          }

          customerUid = newlyCreatedUser.uid;
          isNewCustomerAccount = true;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            return const CustomerCreationResult(
              success: false,
              message:
              'This Gmail already has a Firebase account, but its role is not registered. Please verify the existing account before adding it.',
            );
          }

          rethrow;
        }
      }

      final customerRef =
      _firestore.collection('customers').doc(customerUid);

      final relationshipId = '${adminUid.trim()}__$customerUid';

      final relationshipRef =
      _firestore.collection('admin_customers').doc(relationshipId);

      final legacyCustomerRef =
      _firestore.collection('authorized_users').doc(customerUid);

      await _firestore.runTransaction((transaction) async {
        final roleSnapshot = await transaction.get(emailRoleRef);
        final customerSnapshot = await transaction.get(customerRef);
        final relationshipSnapshot =
        await transaction.get(relationshipRef);
        final legacySnapshot = await transaction.get(legacyCustomerRef);

        if (roleSnapshot.exists) {
          final roleData = roleSnapshot.data();

          if (roleData == null ||
              roleData['role'] != 'customer' ||
              roleData['uid'] != customerUid) {
            throw Exception(
              'This Gmail is already registered with another account role.',
            );
          }
        } else {
          if (!isNewCustomerAccount) {
            throw Exception(
              'Customer role registration changed. Please try again.',
            );
          }

          transaction.set(emailRoleRef, {
            'email': normalizedEmail,
            'uid': customerUid,
            'role': 'customer',
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (relationshipSnapshot.exists) {
          throw Exception(
            'This Customer is already added to your account.',
          );
        }

        // Common Customer profile is created only once.
        if (!customerSnapshot.exists) {
          transaction.set(customerRef, {
            'uid': customerUid,
            'name': cleanName,
            'optionalName': optionalName.trim(),
            'email': normalizedEmail,
            'mobile': mobile.trim(),
            'address': address.trim(),
            'description': description.trim(),
            'role': 'customer',
            'active': true,
            'depositType': cleanDepositType,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Existing Customer's Deposit Type must not be overwritten.
          // Only add it if an older Customer document does not have it.
          final customerData = customerSnapshot.data() ?? {};

          if (customerData['depositType'] == null ||
              customerData['depositType'].toString().trim().isEmpty) {
            transaction.update(customerRef, {
              'depositType': cleanDepositType,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // Each Admin gets an independent Customer relationship.
        transaction.set(relationshipRef, {
          'adminUid': adminUid.trim(),
          'adminName': adminName.isNotEmpty ? adminName : 'Admin',
          'customerUid': customerUid,
          'active': true,
          'accountStatus': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!legacySnapshot.exists) {
          transaction.set(legacyCustomerRef, {
            'uid': customerUid,
            'name': cleanName,
            'optionalName': optionalName.trim(),
            'email': normalizedEmail,
            'mobile': mobile.trim(),
            'address': address.trim(),
            'description': description.trim(),
            'addedBy': adminUid.trim(),
            'role': 'user',
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      bool resetEmailSent = false;

      if (isNewCustomerAccount) {
        try {
          await customerAuth.sendPasswordResetEmail(
            email: normalizedEmail,
          );

          resetEmailSent = true;
        } catch (e) {
          debugPrint('CUSTOMER PASSWORD EMAIL ERROR: $e');
        }
      }

      return CustomerCreationResult(
        success: true,
        passwordResetEmailSent: resetEmailSent,
        message: isNewCustomerAccount
            ? resetEmailSent
            ? 'Customer added successfully. Password setup link has been sent to the Customer Gmail.'
            : 'Customer account created and added successfully, but the password email could not be sent. Please try password reset again.'
            : 'Existing Customer linked successfully with your Admin account.',
      );
    } catch (e, stackTrace) {
      debugPrint('ADD CUSTOMER ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (newlyCreatedUser != null && customerAuth != null) {
        try {
          await newlyCreatedUser.delete();
        } catch (deleteError) {
          debugPrint('CUSTOMER AUTH CLEANUP ERROR: $deleteError');
        }
      }

      return CustomerCreationResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (customerAuth != null) {
        try {
          await customerAuth.signOut();
        } catch (e) {
          debugPrint('CUSTOMER AUTH SIGNOUT ERROR: $e');
        }
      }
    }
  }
}
