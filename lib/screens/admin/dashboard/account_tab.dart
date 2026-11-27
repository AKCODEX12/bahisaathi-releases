import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin_login_screen.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String adminName = 'Admin';
  String adminEmail = '';

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAdminData();
  }

  Future<void> loadAdminData() async {
    final user = _auth.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
      });
      return;
    }

    adminEmail = user.email ?? '';

    try {
      final doc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();

        if (data != null && data['name'] != null) {
          adminName = data['name'];
        }
      }
    } catch (e) {
      // Data load error
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  Future<void> editProfile() async {
    final controller = TextEditingController(text: adminName);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Admin Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  return;
                }

                final user = _auth.currentUser;

                if (user != null) {
                  await _firestore
                      .collection('admins')
                      .doc(user.uid)
                      .update({
                    'name': name,
                  });

                  if (!mounted) return;

                  setState(() {
                    adminName = name;
                  });

                  Navigator.pop(context);

                  showMessage(
                    'Profile updated successfully',
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> changePassword() async {
    final oldPasswordController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscureOldPassword = true;
    bool obscurePassword = true;
    bool obscureConfirm = true;

    bool changingPassword = false;
    bool sendingReset = false;

    String? oldPasswordError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // ==================================================
            // ACTUAL PASSWORD CHANGE
            // ==================================================

            Future<void> changeNow() async {
              final oldPassword =
              oldPasswordController.text.trim();

              final password =
              passwordController.text.trim();

              final confirm =
              confirmController.text.trim();

              // Clear previous error
              setDialogState(() {
                oldPasswordError = null;
              });

              // OLD PASSWORD EMPTY
              if (oldPassword.isEmpty) {
                setDialogState(() {
                  oldPasswordError =
                  'Please enter your old password';
                });
                return;
              }

              // NEW PASSWORD EMPTY
              if (password.isEmpty) {
                showMessage(
                  'Please enter your new password',
                );
                return;
              }

              // NEW PASSWORD LENGTH
              if (password.length < 6) {
                showMessage(
                  'Password must be at least 6 characters',
                );
                return;
              }

              // CONFIRM PASSWORD EMPTY
              if (confirm.isEmpty) {
                showMessage(
                  'Please confirm your new password',
                );
                return;
              }

              // PASSWORD MATCH
              if (password != confirm) {
                showMessage(
                  'Passwords do not match',
                );
                return;
              }

              final user = _auth.currentUser;

              if (user == null) {
                showMessage(
                  'User session expired. Please login again.',
                );
                return;
              }

              final email = user.email;

              if (email == null || email.isEmpty) {
                showMessage(
                  'Account email not found.',
                );
                return;
              }

              setDialogState(() {
                changingPassword = true;
              });

              try {
                // =================================================
                // STEP 1
                // VERIFY OLD PASSWORD
                // =================================================

                final credential =
                EmailAuthProvider.credential(
                  email: email,
                  password: oldPassword,
                );

                await user.reauthenticateWithCredential(
                  credential,
                );

                // =================================================
                // STEP 2
                // CHANGE PASSWORD
                // =================================================

                await user.updatePassword(password);

                if (!mounted) return;

                Navigator.pop(context);

                showMessage(
                  'Password changed successfully',
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;

                // WRONG OLD PASSWORD
                if (e.code == 'wrong-password' ||
                    e.code == 'invalid-credential') {
                  setDialogState(() {
                    changingPassword = false;
                    oldPasswordError = 'Wrong password';
                  });

                  return;
                }

                setDialogState(() {
                  changingPassword = false;
                });

                // RECENT LOGIN REQUIRED
                if (e.code == 'requires-recent-login') {
                  showMessage(
                    'Please login again before changing password',
                  );
                }

                // TOO MANY ATTEMPTS
                else if (e.code == 'too-many-requests') {
                  showMessage(
                    'Too many attempts. Please try again later.',
                  );
                }

                // OTHER FIREBASE ERROR
                else {
                  showMessage(
                    e.message ?? 'Password change failed',
                  );
                }
              } catch (e) {
                if (!mounted) return;

                setDialogState(() {
                  changingPassword = false;
                });

                showMessage(
                  'Something went wrong. Please try again.',
                );
              }
            }

            // ==================================================
            // FORGOT PASSWORD
            // ==================================================

            Future<void> forgotPassword() async {
              final user = _auth.currentUser;

              if (user == null) {
                showMessage(
                  'User session expired. Please login again.',
                );
                return;
              }

              final email = user.email;

              if (email == null || email.isEmpty) {
                showMessage(
                  'Account email not found.',
                );
                return;
              }

              setDialogState(() {
                sendingReset = true;
              });

              try {
                await _auth.sendPasswordResetEmail(
                  email: email,
                );

                if (!mounted) return;

                setDialogState(() {
                  sendingReset = false;
                });

                await showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text(
                        'Reset Link Sent',
                      ),
                      content: Text(
                        'Password reset link has been sent to:\n\n'
                            '$email\n\n'
                            'Please check your inbox or spam folder.',
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;

                setDialogState(() {
                  sendingReset = false;
                });

                showMessage(
                  e.message ??
                      'Could not send password reset link.',
                );
              } catch (e) {
                if (!mounted) return;

                setDialogState(() {
                  sendingReset = false;
                });

                showMessage(
                  'Something went wrong. Please try again.',
                );
              }
            }

            // ==================================================
            // CHANGE PASSWORD POPUP UI
            // ==================================================

            return AlertDialog(
              title: const Text(
                'Change Password',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ==========================================
                    // OLD PASSWORD
                    // ==========================================

                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOldPassword,
                      enabled: !changingPassword,
                      onChanged: (_) {
                        if (oldPasswordError != null) {
                          setDialogState(() {
                            oldPasswordError = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Old Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        border: const OutlineInputBorder(),
                        errorText: oldPasswordError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureOldPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureOldPassword =
                              !obscureOldPassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==========================================
                    // NEW PASSWORD
                    // ==========================================

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      enabled: !changingPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(
                          Icons.lock,
                        ),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword =
                              !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==========================================
                    // CONFIRM PASSWORD
                    // ==========================================

                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      enabled: !changingPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirm =
                              !obscureConfirm;
                            });
                          },
                        ),
                      ),
                    ),

                    // ==========================================
                    // FORGOT PASSWORD
                    // ==========================================

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                        (changingPassword ||
                            sendingReset)
                            ? null
                            : forgotPassword,
                        child: sendingReset
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Forgot Password?',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                // ==============================================
                // CANCEL
                // ==============================================

                TextButton(
                  onPressed: changingPassword
                      ? null
                      : () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),

                // ==============================================
                // CHANGE
                // ==============================================

                ElevatedButton(
                  onPressed:
                  changingPassword ? null : changeNow,
                  child: changingPassword
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );

    oldPasswordController.dispose();
    passwordController.dispose();
    confirmController.dispose();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
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
        builder: (context) => const AdminLoginScreen(),
      ),
          (route) => false,
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        top: 18,
        bottom: 8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ============================================================
  // ACCOUNT ITEM
  // ============================================================

  Widget accountItem({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: CircleAvatar(
        radius: 21,
        backgroundColor:
        (iconColor ?? Colors.green).withOpacity(0.10),
        child: Icon(
          icon,
          color: iconColor ?? Colors.green,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle)
          : null,
      trailing: onTap != null
          ? const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      )
          : null,
      onTap: onTap,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(
      child: CircularProgressIndicator(),
    )
        : ListView(
      padding: const EdgeInsets.only(
        bottom: 24,
      ),
      children: [
        const SizedBox(height: 24),

        // =================================================
        // PROFILE CIRCLE
        // =================================================

        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.green,
            child: Text(
              adminName.isNotEmpty
                  ? adminName[0].toUpperCase()
                  : 'A',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: Text(
            adminName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 4),

        Center(
          child: Text(
            adminEmail,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),

        const SizedBox(height: 5),

        const Center(
          child: Text(
            'ADMIN ACCOUNT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.green,
              letterSpacing: 1,
            ),
          ),
        ),

        const SizedBox(height: 18),

        const Divider(),

        // =================================================
        // PROFILE
        // =================================================

        sectionTitle('PROFILE'),

        accountItem(
          icon: Icons.edit,
          title: 'Edit Profile',
          subtitle: 'Update your name',
          onTap: editProfile,
        ),

        // =================================================
        // BUSINESS SETTINGS
        // =================================================

        sectionTitle('BUSINESS SETTINGS'),

        accountItem(
          icon: Icons.store_outlined,
          title: 'Business / Shop Name',
          subtitle: 'Set your business name',
          onTap: () {
            showMessage(
              'Business / Shop Name will be added here',
            );
          },
        ),

        accountItem(
          icon: Icons.phone_outlined,
          title: 'Mobile Number',
          subtitle: 'Add your mobile number',
          onTap: () {
            showMessage(
              'Mobile Number will be added here',
            );
          },
        ),

        accountItem(
          icon: Icons.location_on_outlined,
          title: 'Address',
          subtitle: 'Add your business address',
          onTap: () {
            showMessage(
              'Address will be added here',
            );
          },
        ),

        accountItem(
          icon: Icons.percent,
          title: 'Interest Settings',
          subtitle: 'Simple / Compound Interest',
          onTap: () {
            showInterestSettings();
          },
        ),

        // =================================================
        // SECURITY
        // =================================================

        sectionTitle('SECURITY'),

        accountItem(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Update your account password',
          onTap: changePassword,
        ),

        accountItem(
          icon: Icons.logout,
          title: 'Logout',
          subtitle: 'Sign out from your account',
          iconColor: Colors.red,
          onTap: logout,
        ),

        // =================================================
        // ABOUT
        // =================================================

        sectionTitle('ABOUT'),

        accountItem(
          icon: Icons.info_outline,
          title: 'About BahiSaathi',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'BahiSaathi',
              applicationVersion: '1.0.0',
              applicationLegalese:
              'Har Len-Den ka Saathi',
            );
          },
        ),

        accountItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () {
            showMessage(
              'Privacy Policy will be added here',
            );
          },
        ),

        accountItem(
          icon: Icons.description_outlined,
          title: 'Terms & Conditions',
          onTap: () {
            showMessage(
              'Terms & Conditions will be added here',
            );
          },
        ),

        accountItem(
          icon: Icons.phone_android,
          title: 'App Version',
          subtitle: 'Version 1.0.0',
        ),
      ],
    );
  }

  // ============================================================
  // INTEREST SETTINGS
  // ============================================================

  void showInterestSettings() {
    String selectedInterest = 'Simple Interest';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Interest Settings',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'Simple Interest',
                    groupValue: selectedInterest,
                    title: const Text(
                      'Simple Interest',
                    ),
                    onChanged: (value) {
                      setState(() {
                        selectedInterest = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    value: 'Compound Interest',
                    groupValue: selectedInterest,
                    title: const Text(
                      'Compound Interest',
                    ),
                    onChanged: (value) {
                      setState(() {
                        selectedInterest = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);

                    showMessage(
                      '$selectedInterest selected',
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}