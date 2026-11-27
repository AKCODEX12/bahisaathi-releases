import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'user_login_screen.dart';
class UserProfileScreen extends StatefulWidget {
  final String customerEmail;
  final String adminUid;

  const UserProfileScreen({
    super.key,
    required this.customerEmail,
    required this.adminUid,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = true;
  bool _savingMobile = false;

  String _name = '';
  String _email = '';
  String _mobile = '';
  String _status = 'Active';

  String? _pendingMobile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD CUSTOMER PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final email = widget.customerEmail.trim().toLowerCase();

      final doc = await _firestore
          .collection('authorized_users')
          .doc(email)
          .get();

      if (!doc.exists) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final data = doc.data()!;

      String mobile = '';

      if (data['mobile'] != null) {
        mobile = data['mobile'].toString();
      } else if (data['mobileNumber'] != null) {
        mobile = data['mobileNumber'].toString();
      }

      String status = 'Active';

      if (data['status'] != null) {
        status = data['status'].toString();
      } else if (data['active'] != null) {
        status = data['active'] == true ? 'Active' : 'Closed';
      }

      if (mounted) {
        setState(() {
          _name = (data['name'] ?? data['customerName'] ?? '').toString();
          _email = (data['email'] ?? email).toString();
          _mobile = mobile;
          _status = status;
          _loading = false;
        });
      }

      await _loadPendingMobile();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });

        _showMessage(
          'Unable to load profile.',
          isError: true,
        );
      }
    }
  }

  // ============================================================
  // CHECK PENDING MOBILE REQUEST
  // ============================================================

  Future<void> _loadPendingMobile() async {
    try {
      final email = widget.customerEmail.trim().toLowerCase();

      final query = await _firestore
          .collection('mobile_change_requests')
          .where('customerEmail', isEqualTo: email)
          .where('adminUid', isEqualTo: widget.adminUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && mounted) {
        final data = query.docs.first.data();

        setState(() {
          _pendingMobile =
              (data['newMobile'] ?? '').toString();
        });
      }
    } catch (_) {
      // Pending request is optional.
      // Profile should still work if no request exists.
    }
  }

  // ============================================================
  // ADD NEW MOBILE NUMBER
  // ============================================================

  Future<void> _showAddMobileDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                color: Color(0xFF35B94B),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add New Mobile Number',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: 'New Mobile Number',
              hintText: 'Enter 10 digit number',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final number = controller.text.trim();

                if (number.length != 10 ||
                    !RegExp(r'^[0-9]{10}$').hasMatch(number)) {
                  _showMessage(
                    'Please enter a valid 10 digit mobile number.',
                    isError: true,
                  );
                  return;
                }

                Navigator.pop(dialogContext);

                await _submitMobileRequest(number);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF35B94B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  // ============================================================
  // SUBMIT MOBILE CHANGE REQUEST
  // ============================================================

  Future<void> _submitMobileRequest(String newMobile) async {
    if (_savingMobile) return;

    setState(() {
      _savingMobile = true;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in.');
      }

      final email = widget.customerEmail.trim().toLowerCase();

      // Check if same number is already the current number.
      if (_mobile == newMobile) {
        _showMessage(
          'This number is already your current mobile number.',
          isError: true,
        );

        if (mounted) {
          setState(() {
            _savingMobile = false;
          });
        }
        return;
      }

      // Check whether there is already a pending request.
      final existing = await _firestore
          .collection('mobile_change_requests')
          .where('customerEmail', isEqualTo: email)
          .where('adminUid', isEqualTo: widget.adminUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        _showMessage(
          'You already have a pending mobile number request.',
          isError: true,
        );

        if (mounted) {
          setState(() {
            _savingMobile = false;
          });
        }
        return;
      }

      // Create a request instead of changing the locked
      // customer record directly.
      await _firestore
          .collection('mobile_change_requests')
          .add({
        'customerEmail': email,
        'customerName': _name,
        'adminUid': widget.adminUid,
        'oldMobile': _mobile,
        'newMobile': newMobile,
        'status': 'pending',
        'requestedBy': user.uid,
        'requestedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _pendingMobile = newMobile;
          _savingMobile = false;
        });
      }

      _showMessage(
        'New mobile number request sent to admin.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingMobile = false;
        });
      }

      _showMessage(
        'Unable to add mobile number. Please try again.',
        isError: true,
      );
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _changePassword() async {
    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      _showMessage(
        'User account not found.',
        isError: true,
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(
        email: user.email!,
      );

      _showMessage(
        'Password reset link has been sent to your Gmail.',
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(
        e.message ?? 'Unable to send password reset email.',
        isError: true,
      );
    } catch (_) {
      _showMessage(
        'Unable to send password reset email.',
        isError: true,
      );
    }
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  Future<void> _verifyEmail() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      await user.reload();

      final refreshedUser = _auth.currentUser;

      if (refreshedUser != null &&
          refreshedUser.emailVerified) {
        _showMessage(
          'Your email is already verified.',
        );
        return;
      }

      await user.sendEmailVerification();

      _showMessage(
        'Verification email has been sent to your Gmail.',
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(
        e.message ?? 'Unable to send verification email.',
        isError: true,
      );
    } catch (_) {
      _showMessage(
        'Unable to send verification email.',
        isError: true,
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const UserLoginScreen(),
      ),
          (route) => false,
    );
  }
  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isError ? Colors.red : const Color(0xFF35B94B),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // PROFILE CIRCLE
  // ============================================================

  Widget _profileCircle() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE9F8EC),
        border: Border.all(
          color: const Color(0xFF35B94B),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 55,
        color: Color(0xFF35B94B),
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
    bool locked = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8E4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF35B94B),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not added' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 2,
        bottom: 12,
        top: 8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF202520),
        ),
      ),
    );
  }

  // ============================================================
  // ACTION TILE
  // ============================================================

  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final iconColor =
    danger ? Colors.red : const Color(0xFF35B94B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8E4),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: danger
                ? const Color(0xFFFFEEEE)
                : const Color(0xFFEAF8ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: danger
                ? Colors.red
                : const Color(0xFF222222),
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE SECTION
  // ============================================================

  Widget _mobileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(
          icon: Icons.phone_outlined,
          title: 'Mobile Number',
          value: _mobile,
          locked: true,
        ),

        if (_pendingMobile != null &&
            _pendingMobile!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFFD76A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.pending_actions_rounded,
                  color: Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New number pending',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pendingMobile!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Your admin has been notified. '
                            'The new number will be updated after admin approval.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        InkWell(
          onTap: _savingMobile ? null : _showAddMobileDialog,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFB9E9C1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _savingMobile
                      ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF35B94B),
                    ),
                  )
                      : const Icon(
                    Icons.add_rounded,
                    color: Color(0xFF35B94B),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Mobile Number',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF267D34),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Admin will be notified about the new number.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF35B94B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F7),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF35B94B),
        foregroundColor: Colors.white,
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF35B94B),
        ),
      )
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            16,
            22,
            16,
            30,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [

              // ==========================================
              // PROFILE HEADER
              // ==========================================

              Center(
                child: Column(
                  children: [
                    _profileCircle(),

                    const SizedBox(height: 12),

                    Text(
                      _name.isEmpty
                          ? 'Customer'
                          : _name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202520),
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Customer',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _status.toLowerCase() ==
                            'active'
                            ? const Color(0xFFE8F8EB)
                            : const Color(0xFFEDEFF1),
                        borderRadius:
                        BorderRadius.circular(30),
                        border: Border.all(
                          color:
                          _status.toLowerCase() ==
                              'active'
                              ? const Color(
                            0xFFB8E7C0,
                          )
                              : const Color(
                            0xFFD5D9DC,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration:
                            BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                              _status.toLowerCase() ==
                                  'active'
                                  ? const Color(
                                0xFF35B94B,
                              )
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Account Status: $_status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.w700,
                              color:
                              _status.toLowerCase() ==
                                  'active'
                                  ? const Color(
                                0xFF267D34,
                              )
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ==========================================
              // ACCOUNT INFORMATION
              // ==========================================

              _sectionTitle('ACCOUNT INFORMATION'),

              _infoRow(
                icon: Icons.person_outline_rounded,
                title: 'Customer Name',
                value: _name,
                locked: true,
              ),

              _infoRow(
                icon: Icons.badge_outlined,
                title: 'Account Type',
                value: 'Customer',
                locked: true,
              ),

              _infoRow(
                icon: Icons.email_outlined,
                title: 'Gmail',
                value: _email,
                locked: true,
              ),

              // ==========================================
              // MOBILE
              // ==========================================

              const SizedBox(height: 6),

              _sectionTitle('MOBILE NUMBER'),

              _mobileSection(),

              // ==========================================
              // SECURITY
              // ==========================================

              const SizedBox(height: 12),

              _sectionTitle('ACCOUNT SECURITY'),

              _actionTile(
                icon: Icons.lock_reset_rounded,
                title: 'Change Password',
                subtitle:
                'Receive a password reset link on Gmail',
                onTap: _changePassword,
              ),

              _actionTile(
                icon: Icons.mark_email_read_outlined,
                title: 'Email Verification',
                subtitle:
                'Verify your BahiSaathi account email',
                onTap: _verifyEmail,
              ),

              // ==========================================
              // APP
              // ==========================================

              const SizedBox(height: 12),

              _sectionTitle('APP'),

              _actionTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & Contact Admin',
                subtitle:
                'Contact your admin for account help',
                onTap: () {
                  _showMessage(
                    'Please contact your admin for assistance.',
                  );
                },
              ),

              _actionTile(
                icon: Icons.info_outline_rounded,
                title: 'About BahiSaathi',
                subtitle:
                'Digital Bahi & Loan Management',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'BahiSaathi',
                    applicationVersion: '1.0.0',
                    applicationIcon: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFFEAF8ED),
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color:
                        Color(0xFF35B94B),
                      ),
                    ),
                    children: const [
                      Text(
                        'BahiSaathi is a digital bahi and '
                            'loan management application.',
                      ),
                    ],
                  );
                },
              ),

              // ==========================================
              // LOGOUT
              // ==========================================

              const SizedBox(height: 14),

              _actionTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle:
                'Sign out from your BahiSaathi account',
                onTap: _logout,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}