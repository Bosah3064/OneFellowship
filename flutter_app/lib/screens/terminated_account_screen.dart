import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

class TerminatedAccountScreen extends StatelessWidget {
  static const String route = '/terminated-account';

  final Map<String, dynamic>? memberData;

  const TerminatedAccountScreen({Key? key, this.memberData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final data = memberData ?? routeArgs ?? {};
    final reason = (data['termination_reason'] ?? data['reason'] ?? 'Disciplinary action under Article 7 of the Welfare Constitution.').toString();
    final terminatedAt = data['terminated_at']?.toString();
    final terminatedBy = (data['terminated_by'] ?? 'Executive Leadership Office').toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branded Red / Gold Crest
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1C2541),
                    border: Border.all(color: const Color(0xFFEF4444), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.gavel_rounded,
                        color: Color(0xFFEF4444),
                        size: 44,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'MEMBERSHIP TERMINATED',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFCA5A5),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'OneFellowship Benevolent Welfare Fund',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD4AF37),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),

                // Main Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF991B1B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.block_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'ACCESS REVOKED',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (terminatedAt != null && terminatedAt.length >= 10)
                            Text(
                              terminatedAt.substring(0, 10),
                              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Reason for Termination:',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFCA5A5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          reason,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Enacted Authority:',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFCA5A5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        terminatedBy,
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF334155)),
                      const SizedBox(height: 12),

                      // Article 7 Constitutional Safeguard Notice
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFD4AF37), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Constitution Article 7 Notice:\nYour registered Next of Kin has been officially notified of this termination proceeding. Active welfare cover, savings claims, and voting rights are fully suspended.',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: const Color(0xFFCBD5E1),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.gavel_rounded, color: Color(0xFF60A5FA), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Appeals Process:\nIf you believe this decision was made in error or wish to request an executive leadership review, please contact Church Administration.',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: const Color(0xFF94A3B8),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sign Out & Return to Login
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    onPressed: () async {
                      await SupabaseService.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          LoginScreen.route,
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: Text(
                      'Sign Out / Switch Account',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Helpline Notice
                Text(
                  'OneFellowship Church Governance • 1st Corinthians 14:40',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white38,
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
