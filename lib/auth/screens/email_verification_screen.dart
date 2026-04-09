import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  late Timer _checkTimer;
  Timer? _resendTimer;
  bool _isResending = false;
  bool _canResend = true;
  int _resendCountdown = 60;
  String? _errorMessage;
  String? _successMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.95, end: 1.05).animate(_pulseController);

    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkVerification();
    });
  }

  Future<void> _checkVerification() async {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    await authService.reloadCurrentUser();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified && mounted) {
      _checkTimer.cancel();
      // AuthWrapper will automatically redirect
    }
  }

  Future<void> _resendEmail() async {
    if (!_canResend) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await context.read<AuthService>().sendEmailVerification();
      setState(() => _successMessage = 'Email renvoyé ! Vérifiez votre boîte mail.');
      _startResendCountdown();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startResendCountdown() {
    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  @override
  void dispose() {
    _checkTimer.cancel();
    _resendTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final email = authService.currentFirebaseUser?.email ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0F3), Color(0xFFFCE4EC), Color(0xFFEDE9FE)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Animated envelope
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.mark_email_unread_rounded,
                              color: AppColors.primary, size: 52),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'Vérifiez votre email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Un email de vérification a été envoyé à :',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textMedium),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.07),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _infoRow(Icons.check_circle_outline_rounded,
                              'Cliquez sur le lien dans votre email'),
                          const SizedBox(height: 12),
                          _infoRow(Icons.refresh_rounded,
                              'Revenez et l\'app vous connectera automatiquement'),
                          const SizedBox(height: 12),
                          _infoRow(Icons.folder_outlined,
                              'Vérifiez vos spams si vous ne le trouvez pas'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_errorMessage!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_successMessage!,
                            style: TextStyle(
                                color: Colors.green.shade700, fontSize: 13),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Resend button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (_canResend && !_isResending) ? _resendEmail : null,
                        icon: _isResending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Icon(Icons.send_rounded),
                        label: Text(_canResend
                            ? 'Renvoyer l\'email'
                            : 'Renvoyer dans $_resendCountdown s'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign out
                    TextButton.icon(
                      onPressed: () => context.read<AuthService>().signOut(),
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.textMedium, size: 18),
                      label: const Text('Se déconnecter',
                          style: TextStyle(color: AppColors.textMedium)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMedium)),
        ),
      ],
    );
  }
}
