import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase_options.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/admin/widgets/floating_calculator_overlay.dart';

class BahiSaathiApp extends StatelessWidget {
  const BahiSaathiApp({super.key});

  static final Future<void> _firebaseInitFuture = _initFirebaseOnce();

  static Future<void> _initFirebaseOnce() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BahiSaathi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      builder: (context, child) {
        return FutureBuilder<void>(
          future: _firebaseInitFuture,
          builder: (context, firebaseSnap) {
            if (firebaseSnap.connectionState != ConnectionState.done) {
              return child ?? const SizedBox.shrink();
            }

            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              initialData: FirebaseAuth.instance.currentUser,
              builder: (context, snapshot) {
                final user = snapshot.data;

                // Login nahi hai to calculator mat dikhao
                if (user == null) {
                  return child ?? const SizedBox.shrink();
                }

                // Login ke baad poore app par calculator
                return FloatingCalculatorOverlay(
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
    );
  }
}
