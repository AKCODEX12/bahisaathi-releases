
import 'package:flutter/material.dart';

class AdminLoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  final bool obscurePassword;
  final bool isLoading;
  final bool isResettingPassword;

  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignup;
  final VoidCallback onTogglePassword;
  final VoidCallback onSwitchToUser;

  const AdminLoginForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.isResettingPassword,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onSignup,
    required this.onTogglePassword,
    required this.onSwitchToUser,
  });

  static const Color _green = Color(0xFF16834A);
  static const Color _darkGreen = Color(0xFF10663A);

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
        borderSide: const BorderSide(
          color: _green,
          width: 1.7,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F4),
      appBar: AppBar(
        title: const Text(
          'Admin Login',
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
                key: formKey,
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
                            selected: false,
                            onPressed: onSwitchToUser,
                          ),
                          const SizedBox(width: 5),
                          _roleButton(
                            label: 'ADMIN',
                            selected: true,
                            onPressed: () {},
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
                              Icons.admin_panel_settings_rounded,
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
                            'Login to manage your BahiSaathi account',
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
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your Gmail';
                              }

                              if (!value.trim().contains('@')) {
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
                            decoration: _inputDecoration(
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                onPressed: onTogglePassword,
                                tooltip: obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.black54,
                                ),
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
                            onFieldSubmitted: (_) {
                              if (!isLoading) {
                                onLogin();
                              }
                            },
                          ),

                          const SizedBox(height: 7),

                          // FORGOT PASSWORD
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isResettingPassword
                                  ? null
                                  : onForgotPassword,
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
                                'Forgot Password?',
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
                              onPressed: isLoading ? null : onLogin,
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

                          const SizedBox(height: 25),

                          // DIVIDER
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                ),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),

                          const SizedBox(height: 17),

                          // SIGNUP
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(color: Colors.black54),
                              ),
                              TextButton(
                                onPressed: onSignup,
                                style: TextButton.styleFrom(
                                  foregroundColor: _darkGreen,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                                child: const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
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
