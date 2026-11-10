import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';
import '../services/biometric_service.dart';
import '../services/offline_cache_service.dart';
import '../services/role_permissions.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _member;
  bool _isLoading = true;
  bool _voiceGreetingEnabled = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  int? _localSelectedTheme;

  String _getAccountNumber() {
    if (_member == null) return 'N/A';
    if (_member!['member_number'] != null && _member!['member_number'].toString().trim().isNotEmpty) {
      return _member!['member_number'].toString();
    }
    final String uuid = _member!['id'].toString().replaceAll('-', '');
    String digits = '';
    for (int i = 0; i < uuid.length; i++) {
      digits += (uuid.codeUnitAt(i) % 10).toString();
      if (digits.length >= 16) break;
    }
    if (digits.length < 16) digits = digits.padRight(16, '0');
    return '${digits.substring(0,4)} ${digits.substring(4,8)} ${digits.substring(8,12)} ${digits.substring(12,16)}';
  }

  @override
  void initState() {
    super.initState();
    _loadMember();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final bioAvail = await BiometricService.isBiometricAvailable();
    final bioEnabled = await BiometricService.isBiometricEnabled();
    setState(() {
      _voiceGreetingEnabled = prefs.getBool('voice_greeting') ?? true;
      _biometricAvailable = bioAvail;
      _biometricEnabled = bioEnabled;
    });
  }

  Future<void> _toggleVoiceGreeting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_greeting', value);
    setState(() {
      _voiceGreetingEnabled = value;
    });
  }

  Future<void> _loadMember() async {
    try {
      final member = await SupabaseService.fetchCurrentMember();
      final theme = await OfflineCacheService.getPreferredTheme();
      if (mounted) {
        setState(() {
          _member = member;
          _localSelectedTheme = theme;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, LoginScreen.route, (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Future<void> _updateTheme(int index) async {
    // 1. Instant optimistic UI update (0ms delay!)
    setState(() {
      _localSelectedTheme = index;
      if (_member != null) {
        final fd = Map<String, dynamic>.from(_member!['form_details'] as Map? ?? {});
        fd['card_theme'] = index;
        _member!['form_details'] = fd;
      }
    });

    // 2. Instant persistent local storage
    await OfflineCacheService.setPreferredTheme(index);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card theme applied!', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    // 3. Background remote sync
    try {
      await SupabaseService.updateCardTheme(index);
    } catch (e) {
      debugPrint('Background card theme sync error: $e');
    }
  }

  Widget _buildThemeCircle(int index, List<Color> colors, int currentTheme) {
    final isSelected = index == currentTheme;
    return GestureDetector(
      onTap: () => _updateTheme(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: isSelected ? Border.all(color: AppColors.textPrimary, width: 3) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.first.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 24) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final name = _member?['full_name']?.toString() ?? user?.email ?? 'Member';
    final email = _member?['email']?.toString() ?? user?.email ?? '';
    final phone = _member?['phone']?.toString() ?? 'Not set';
    final status = _member?['status']?.toString() ?? 'active';
    final role = _member?['role']?.toString() ?? 'member';
    final joinDate = _member?['join_date']?.toString() ?? '';
    final formDetails = _member?['form_details'] as Map<String, dynamic>? ?? {};
    final currentTheme = _localSelectedTheme ?? (formDetails['card_theme'] as int? ?? 0);

    final nameParts = name.split(' ').where((s) => s.isNotEmpty).toList();
    final initials = nameParts.length >= 2 
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : nameParts.isNotEmpty ? nameParts[0].substring(0, 1).toUpperCase() : 'M';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF3F4F6)),
                              ),
                              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Settings',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Profile card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.purple],
                              ),
                              shape: BoxShape.circle, // Made Circular
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                    if (role != 'member') ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.purple.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          role.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.purple,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Card Theme Selection
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card Theme',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildThemeCircle(0, const [Color(0xFF0A2D6B), Color(0xFF0B4FBB), Color(0xFF29B6F6)], currentTheme),
                              _buildThemeCircle(1, const [Color(0xFF0891b2), Color(0xFF1e40af), Color(0xFF3730a3)], currentTheme),
                              _buildThemeCircle(2, const [Color(0xFFe11d48), Color(0xFFf97316), Color(0xFFeab308)], currentTheme),
                              _buildThemeCircle(3, const [Color(0xFF059669), Color(0xFF0d9488), Color(0xFF06b6d4)], currentTheme),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Info section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text(
                      'Account Details',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        children: [
                          _buildActionRow(Icons.assignment_ind_rounded, 'Membership Profile & KYC Form', () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
                            );
                            _loadMember();
                          }),
                          _buildDivider(),
                          _buildInfoRow(Icons.phone_rounded, 'Phone', phone),
                          _buildDivider(),
                          _buildInfoRow(Icons.calendar_today_rounded, 'Member Since', joinDate),
                          _buildDivider(),
                          _buildInfoRow(Icons.badge_rounded, 'Account Number', _getAccountNumber()),
                        ],
                      ),
                    ),
                  ),
                ),

                // App Preferences section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text(
                      'App Preferences & Security',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            activeColor: AppColors.primary,
                            title: Text('Voice Greeting', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            subtitle: Text('Welcome message on startup', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                            secondary: const Icon(Icons.record_voice_over_rounded, color: AppColors.primary, size: 24),
                            value: _voiceGreetingEnabled,
                            onChanged: _toggleVoiceGreeting,
                          ),
                          if (_biometricAvailable) ...[
                            _buildDivider(),
                            SwitchListTile(
                              activeColor: AppColors.primary,
                              title: Text('Fingerprint / Biometric Unlock', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              subtitle: Text('Unlock OneFellowship securely using fingerprint', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                              secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 24),
                              value: _biometricEnabled,
                              onChanged: (val) async {
                                if (val) {
                                  final authenticated = await BiometricService.authenticate(
                                    reason: 'Scan fingerprint to enable biometric unlock for OneFellowship',
                                  );
                                  if (authenticated) {
                                    await BiometricService.setBiometricEnabled(true);
                                    setState(() => _biometricEnabled = true);
                                  }
                                } else {
                                  await BiometricService.setBiometricEnabled(false);
                                  setState(() => _biometricEnabled = false);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Admin Controls (Granular RBAC: Admin, Treasury, Chairperson)
                if (RolePermissions.isLeadership(role)) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Row(
                        children: [
                          Text(
                            'Leadership & Governance',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: RolePermissions.getRoleColor(role).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              RolePermissions.getRoleDisplayName(role).toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: RolePermissions.getRoleColor(role),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: Column(
                          children: [
                            if (RolePermissions.hasPermission(role, AppPermission.manageMembers)) ...[
                              _buildActionRow(Icons.group_rounded, 'Manage Members & Roles', () {
                                Navigator.pushNamed(context, '/manage-members');
                              }),
                              _buildDivider(),
                            ],
                            if (RolePermissions.hasPermission(role, AppPermission.managePayments)) ...[
                              _buildActionRow(Icons.receipt_long_rounded, 'Manage Payments & Ledger', () {
                                Navigator.pushNamed(context, '/manage-payments');
                              }),
                              _buildDivider(),
                            ],
                            if (RolePermissions.hasPermission(role, AppPermission.sendNotifications)) ...[
                              _buildActionRow(Icons.campaign_rounded, 'Send Broadcast Notifications', () {
                                Navigator.pushNamed(context, '/manage-notifications');
                              }),
                              _buildDivider(),
                            ],
                            if (RolePermissions.hasPermission(role, AppPermission.manageWallet)) ...[
                              _buildActionRow(Icons.account_balance_wallet_rounded, 'Organization Wallet & Approvals', () {
                                Navigator.pushNamed(context, '/admin-wallet');
                              }),
                              _buildDivider(),
                            ],
                            if (RolePermissions.hasPermission(role, AppPermission.manageFeedback)) ...[
                              _buildActionRow(Icons.inbox_rounded, 'Member Feedback & Concerns (Admin)', () {
                                Navigator.pushNamed(context, '/admin-feedback');
                              }),
                              _buildDivider(),
                            ],
                            if (RolePermissions.hasPermission(role, AppPermission.viewAuditLogs)) ...[
                              _buildActionRow(Icons.security_rounded, 'Security & Audit Logs (Admin Only)', () {
                                Navigator.pushNamed(context, '/admin-audit-logs');
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // Member Services & Feedback (Available to all members)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text(
                      'MEMBER SERVICES & FEEDBACK',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        children: [
                          _buildActionRow(Icons.feedback_outlined, 'Submit Feedback & Concerns', () {
                            Navigator.pushNamed(context, '/feedback');
                          }),
                          _buildDivider(),
                          _buildActionRow(Icons.menu_book_rounded, 'Welfare Constitution & Policies', () {
                            Navigator.pushNamed(context, '/terms-and-conditions');
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sign out
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: GestureDetector(
                      onTap: _signOut,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withOpacity(0.15)),
                        ),
                        child: Center(
                          child: Text(
                            'Sign Out',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // App Info section (Placed at the bottom)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text(
                      'App Information',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.info_outline_rounded, 'App Name', 'OneFellowship'),
                          _buildDivider(),
                          _buildInfoRow(Icons.verified_rounded, 'Version', '1.0.0 (Production)'),
                          _buildDivider(),
                          _buildInfoRow(Icons.security_rounded, 'Security', 'Encrypted & Biometric Protected'),
                        ],
                      ),
                    ),
                  ),
                ),

                // Developer section (The absolute last section at the bottom)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text(
                      'Developer Info',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.person_rounded, 'Lead Developer', 'LAMECK BOSIRE'),
                          _buildDivider(),
                          _buildInfoRow(Icons.email_rounded, 'Email', 'LAME3064@GMAIL.COM'),
                          _buildDivider(),
                          _buildInfoRow(Icons.phone_rounded, 'Direct Phone', '0790397468'),
                        ],
                      ),
                    ),
                  ),
                ),

                // Safe Area bottom spacing to prevent navigation bar overlap
                SliverToBoxAdapter(
                  child: SizedBox(height: MediaQuery.of(context).padding.bottom + 48),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 14),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 50, color: Color(0xFFF3F4F6));
  }
}
