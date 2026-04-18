import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../routing/role_router.dart';
import '../../features/onboarding/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        /// 🔹 Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        /// 🔹 User Logged In
        if (snapshot.hasData) {
          return const RoleRouter();
        }

        /// 🔹 User Logged Out
        return const HomeScreen();
      },
    );
  }
}

/// 🔥 شاشة تحميل نظيفة (بدال Scaffold عادي)
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}