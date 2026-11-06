import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../services/supabase_service.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  static const route = '/register';

  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.signUp(name, email, password);

      if (!mounted) return;
      // After sign up, log them in (Supabase usually logs them in automatically on sign up)
      // We navigate to the dashboard where the Profile Completion popup will show
      Navigator.pushReplacementNamed(context, DashboardScreen.route);
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
        fontSize: 15,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Gradient Accent Strip ──
          Container(
            width: double.infinity,
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.purple, AppColors.red],
              ),
            ),
          ),

          // ── Content ──
          Expanded(
            child: SafeArea(
              top: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // ── Custom Header ──
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Register',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // ── Heading ──
                    Text(
                      'Create Account',
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black87, height: 1.2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Join Glamorous Care Initiative today.\nComplete your profile after signing up.',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.grey.shade500, height: 1.5),
                    ),

                    const SizedBox(height: 32),

                    // ── Full Name Field ──
                    Text('Full Name', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.outfit(fontSize: 15),
                      decoration: _inputDecoration(hint: 'John Doe', prefixIcon: Icons.person_outline),
                    ),

                    const SizedBox(height: 20),

                    // ── Email Field ──
                    Text('Email Address', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.outfit(fontSize: 15),
                      decoration: _inputDecoration(hint: 'you@example.com', prefixIcon: Icons.email_outlined),
                    ),

                    const SizedBox(height: 20),

                    // ── Password Field ──
                    Text('Password', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                      style: GoogleFonts.outfit(fontSize: 15),
                      decoration: _inputDecoration(
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade400,
                            size: 22,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // ── Terms & Policies Link ──
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/terms-and-conditions'),
                        child: Text.rich(
                          TextSpan(
                            text: 'By creating an account, you agree to our ',
                            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
                            children: [
                              TextSpan(
                                text: 'Terms & Policies',
                                style: GoogleFonts.outfit(
                                  fontSize: 13, 
                                  color: AppColors.primary, 
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Register Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text('Create Account', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Already have account ──
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade500),
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
