import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../services/biometric_service.dart';
import '../services/supabase_service.dart';
import 'complete_profile_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class BiometricUnlockScreen extends StatefulWidget {
  static const route = '/biometric-unlock';

  final String targetRoute;

  const BiometricUnlockScreen({
    super.key,
    this.targetRoute = DashboardScreen.route,
  });

  @override
  State<BiometricUnlockScreen> createState() => _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  bool _isAuthenticating = false;
  String _statusMessage = 'Touch the fingerprint sensor to unlock';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptBiometric();
    });
  }

  Future<void> _promptBiometric() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Verifying fingerprint...';
    });

    try {
      final success = await BiometricService.authenticate(
        reason: 'Scan your fingerprint to unlock OneFellowship',
      );

      if (!mounted) return;

      if (success) {
        final u = SupabaseService.currentUser;
        if (u != null) {
          final isComplete = await SupabaseService.isProfileComplete(u.id);
          if (!isComplete && mounted) {
            Navigator.pushReplacementNamed(context, CompleteProfileScreen.route);
            return;
          }
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, widget.targetRoute);
      } else {
        setState(() {
          _statusMessage = 'Biometric scan cancelled. Tap icon to retry.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Biometric error: tap to retry';
        });
      }
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final displayName = user?.displayName ?? 'Member';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container
                Container(
                  width: 90,
                  height: 90,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'OneFellowship',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back, $displayName',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // Fingerprint Interactive Icon
                GestureDetector(
                  onTap: _isAuthenticating ? null : _promptBiometric,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),

                // Alternative: Sign In with Password
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, LoginScreen.route);
                  },
                  icon: const Icon(Icons.password_rounded, color: AppColors.primary, size: 20),
                  label: Text(
                    'Log in with Email & Password',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
