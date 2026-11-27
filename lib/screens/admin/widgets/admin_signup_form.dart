
import 'package:flutter/material.dart';

class AdminSignupForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  final bool loading;
  final bool obscurePassword;
  final bool rememberPassword;

  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onSignup;
  final VoidCallback onLogin;

  const AdminSignupForm({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.obscurePassword,
    required this.rememberPassword,
    required this.onTogglePassword,
    required this.onRememberChanged,
    required this.onSignup,
    required this.onLogin,
  });

  static const Color _green = Color(0xFF16834A);

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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
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
                          color: const Color(0xFF174D2D).withOpacity(0.07),
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
                            Icons.admin_panel_settings_rounded,
                            size: 49,
                            color: _green,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Create Admin Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF193B28),
                          ),
                        ),

                        const SizedBox(height: 7),

                        const Text(
                          'Start managing your digital Bahi Khata',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // NAME

                        TextField(
                          controller: nameController,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: _inputDecoration(
                            label: 'Full Name',
                            hint: 'Enter your name',
                            icon: Icons.person_outline_rounded,
                          ),
                        ),

                        const SizedBox(height: 19),

                        // EMAIL

                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: _inputDecoration(
                            label: 'Gmail / Email',
                            hint: 'example@gmail.com',
                            icon: Icons.email_outlined,
                          ),
                        ),

                        const SizedBox(height: 19),

                        // PASSWORD

                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [
                            AutofillHints.newPassword,
                          ],
                          decoration: _inputDecoration(
                            label: 'Password',
                            hint: 'Create a password',
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
                              onPressed: onTogglePassword,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // REMEMBER PASSWORD

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAF8),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: rememberPassword,
                                activeColor: _green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                onChanged: loading
                                    ? null
                                    : (value) {
                                  onRememberChanged(value ?? false);
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  'Remember password',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.security_rounded,
                                size: 19,
                                color: Colors.grey.shade500,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // SIGNUP BUTTON

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: loading ? null : onSignup,
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
                              child: loading
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
                                key: ValueKey('signup'),
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Create Admin Account',
                                    style: TextStyle(
                                      fontSize: 16,
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

                        const SizedBox(height: 23),

                        // DIVIDER

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                              ),
                              child: Text(
                                'ALREADY REGISTERED?',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // LOGIN

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: loading ? null : onLogin,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _green,
                              side: const BorderSide(
                                color: _green,
                                width: 1.3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 20),
                                SizedBox(width: 9),
                                Text(
                                  'Login to Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 19),

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
                        'Secure Admin Registration - BahiSaathi',
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
    );
  }
}
