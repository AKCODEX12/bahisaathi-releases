import 'package:flutter/material.dart';

import 'admin_login_screen.dart';
import 'admin_signup_screen.dart';

class AdminAuthScreen extends StatelessWidget {
  const AdminAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 80,
            ),

            const SizedBox(height: 20),

            const Text(
              'Admin Account',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminLoginScreen(),
                    ),
                  );
                },
                child: const Text('Login'),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminSignupScreen(),
                    ),
                  );
                },
                child: const Text('Signup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}