import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/supabase_service.dart';
import '../services/role_permissions.dart';
import '../app_colors.dart';

/// A guard widget that wraps protected screens and checks the current user's
/// role before granting access.
///
/// Usage (typically in route definitions):
/// ```dart
/// RoleGuard(
///   requiredPermission: AppPermission.manageMembers,
///   child: MemberManagementScreen(),
/// )
/// ```
class RoleGuard extends StatefulWidget {
  /// The permission the current user must hold to view [child].
  final AppPermission requiredPermission;

  /// The screen to display when the user is authorised.
  final Widget child;

  const RoleGuard({
    super.key,
    required this.requiredPermission,
    required this.child,
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _loading = true;
  bool _authorized = false;
  String _userRole = 'member';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final member = await SupabaseService.fetchCurrentMember();
      if (member != null) {
        final role = (member['role'] as String?) ?? 'member';
        final name = (member['name'] as String?) ??
            (member['full_name'] as String?) ??
            '';

        final hasAccess =
            RolePermissions.hasPermission(role, widget.requiredPermission);

        if (mounted) {
          setState(() {
            _userRole = role;
            _userName = name;
            _authorized = hasAccess;
            _loading = false;
          });
        }

        // Log unauthorized access attempts
        if (!hasAccess) {
          _logUnauthorizedAttempt();
        }
      } else {
        // No member data — deny access
        if (mounted) {
          setState(() {
            _loading = false;
            _authorized = false;
          });
        }
      }
    } catch (e) {
      debugPrint('RoleGuard._checkAccess error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _authorized = false;
        });
      }
    }
  }

  /// Logs the unauthorized access attempt to the audit trail.
  void _logUnauthorizedAttempt() {
    try {
      SupabaseService.logAuditEvent(
        action: 'UNAUTHORIZED_ACCESS_ATTEMPT',
        title: 'Access Denied',
        description:
            '$_userName ($_userRole) attempted to access ${widget.requiredPermission.name}',
        category: 'security',
        performedBy: _userName,
        performedById: SupabaseService.currentUser?.id ?? '',
      ).catchError((_) {});
    } catch (_) {
      // Silently swallow — audit logging should never block the UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading state ──────────────────────────────────────────────────
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // ── Authorized ─────────────────────────────────────────────────────
    if (_authorized) {
      return widget.child;
    }

    // ── Access Denied ──────────────────────────────────────────────────
    final displayRoleName = RolePermissions.getRoleDisplayName(_userRole);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Access Restricted',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Shield icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 80,
                  color: AppColors.error,
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                'Insufficient Privileges',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Your current role ($displayRoleName) does not have '
                'permission to access this area.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Required clearance
              Text(
                'Required clearance: ${widget.requiredPermission.name}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // Info card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.skyBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.primary.withOpacity(0.7),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Contact your Chairperson or Administrator to '
                        'request elevated access.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Go Back button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '← Go Back',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
