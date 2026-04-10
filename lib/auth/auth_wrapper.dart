import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/email_verification_screen.dart';
import '../screnns/admin_dashboard_screen.dart';
import '../screnns/home_screen.dart';

const _adminEmail = 'heyhappyproject@gmail.com';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();

    if (user == null) {
      return const LoginScreen();
    }

    if (!user.emailVerified) {
      return const EmailVerificationScreen();
    }

    // Route admin vers le dashboard dédié
    if (user.email?.toLowerCase() == _adminEmail) {
      return const AdminDashboardScreen();
    }

    return const HomeScreen();
  }
}
