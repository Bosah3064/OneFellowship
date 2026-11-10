import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../widgets/action_tile.dart';

class AdminPanelScreen extends StatelessWidget {
  static const route = '/admin';
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: Text(
          'Admin & Leadership Panel',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administrative Controls',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage membership, disbursements, payments, and security logs in line with welfare constitution.',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'CORE GOVERNANCE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              ActionTile(
                icon: Icons.group_rounded,
                label: 'Manage Members & Roles',
                onTap: () => Navigator.pushNamed(context, '/manage-members'),
              ),
              const SizedBox(height: 10),

              ActionTile(
                icon: Icons.receipt_long_rounded,
                label: 'Manage Payments & Ledger',
                onTap: () => Navigator.pushNamed(context, '/manage-payments'),
              ),
              const SizedBox(height: 10),

              ActionTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Organization Wallet & Approvals',
                onTap: () => Navigator.pushNamed(context, '/admin-wallet'),
              ),
              const SizedBox(height: 10),

              ActionTile(
                icon: Icons.campaign_rounded,
                label: 'Send Broadcast Notifications',
                onTap: () => Navigator.pushNamed(context, '/manage-notifications'),
              ),
              const SizedBox(height: 10),

              ActionTile(
                icon: Icons.inbox_rounded,
                label: 'Member Feedback & Concerns',
                onTap: () => Navigator.pushNamed(context, '/admin-feedback'),
              ),
              const SizedBox(height: 24),

              Text(
                'SECURITY & ACCOUNTABILITY',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              ActionTile(
                icon: Icons.security_rounded,
                label: 'Security & Audit Logs (Clause 6 & 8)',
                onTap: () => Navigator.pushNamed(context, '/admin-audit-logs'),
              ),
              const SizedBox(height: 10),

              ActionTile(
                icon: Icons.gavel_rounded,
                label: 'Welfare Constitution & Policies',
                onTap: () => Navigator.pushNamed(context, '/terms-and-conditions'),
              ),
              const SizedBox(height: 10),

              ActionTile(
                icon: Icons.file_upload_outlined,
                label: 'Import Historical Data',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data import ready for CSV/Excel upload')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
