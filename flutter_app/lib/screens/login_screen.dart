import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../services/supabase_service.dart';
import '../services/biometric_service.dart';
import 'complete_profile_screen.dart';
import 'dashboard_screen.dart';
import 'force_change_password_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'terminated_account_screen.dart';

class LoginScreen extends StatefulWidget {
  static const route = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _canUseBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final available = await BiometricService.isBiometricAvailable();
      final enabled = await BiometricService.isBiometricEnabled();
      final user = SupabaseService.currentUser;
      if (available && enabled && user != null && mounted) {
        setState(() => _canUseBiometric = true);
      }
    } catch (_) {}
  }

  Future<void> _unlockWithBiometrics() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      _showError('Please sign in with email & password once to activate biometric login.');
      return;
    }

    final success = await BiometricService.authenticate(
      reason: 'Scan your fingerprint to unlock your OneFellowship account',
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Fingerprint verified! Opening account...', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final isComplete = await SupabaseService.isProfileComplete(user.id);
      if (!isComplete && mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          CompleteProfileScreen.route,
          (route) => false,
        );
        return;
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, DashboardScreen.route, (route) => false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final memberData = await SupabaseService.signIn(email, password);

      if (!mounted) return;

      // 1. Check if account is terminated
      if (memberData != null && (memberData['status'] == 'terminated' || memberData['is_terminated'] == true)) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          TerminatedAccountScreen.route,
          (route) => false,
          arguments: memberData,
        );
        return;
      }

      // 2. Check if admin required password reset
      if (memberData != null && memberData['requires_password_reset'] == true) {
        Navigator.pushReplacementNamed(context, ForceChangePasswordScreen.route);
        return;
      }

      // 3. Fast local/in-memory profile completion check (zero extra network lag)
      final isComplete = SupabaseService.isMemberDataComplete(memberData);
      if (!isComplete && mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          CompleteProfileScreen.route,
          (route) => false,
        );
        return;
      }

      // 4. Instant entry to dashboard
      Navigator.pushNamedAndRemoveUntil(context, DashboardScreen.route, (route) => false);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(
        color: Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2F7),
      body: isWide ? _buildWideLayout(context) : _buildMobileLayout(context),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DESKTOP & TABLET: SPLIT TWO-SIDED CARD LAYOUT
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildWideLayout(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 940, maxHeight: 660),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.12),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // ── Left Side: Branded Hero Panel ──
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary, AppColors.skyBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo Badge
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'OneFellowship',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TOGETHER WE STAND',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Empowering members through structured welfare savings, virtual identification, and transparent fellowship leadership.',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildPill(Icons.verified_user_rounded, 'Secure Firebase Infrastructure'),
                      const SizedBox(height: 12),
                      _buildPill(Icons.credit_card_rounded, 'Digital Virtual Membership ID'),
                      const SizedBox(height: 12),
                      _buildPill(Icons.savings_rounded, 'Real-time Contribution Ledger'),
                    ],
                  ),
                ),
              ),

              // ── Right Side: Clean Form Panel ──
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormHeader(),
                      const SizedBox(height: 28),
                      _buildFormFields(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MOBILE: TOP BRANDED CARD + FLOATING BOTTOM CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // ── Top Branded Hero Banner ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Back Button Row
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Logo in White Badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'OneFellowship',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'TOGETHER WE STAND',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ),

        // ── Floating White Form Card ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormHeader(),
                    const SizedBox(height: 24),
                    _buildFormFields(),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 28),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FORM HEADER
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFormHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign In',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your credentials to access your portal.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FORM FIELDS & BUTTONS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: GoogleFonts.outfit(fontSize: 14),
          decoration: _inputDecoration(
            hint: 'you@example.com',
            prefixIcon: Icons.email_outlined,
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'Password',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
          style: GoogleFonts.outfit(fontSize: 14),
          decoration: _inputDecoration(
            hint: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, ResetPasswordScreen.route),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot password?',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button with Gradient
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    'Sign In',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (_canUseBiometric) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _unlockWithBiometrics,
              icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 24),
              label: Text(
                'Unlock with Fingerprint',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Register Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, RegisterScreen.route);
              },
              child: Text(
                'Register',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPill(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppColors.secondary),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
