import 'package:flutter/material.dart';

/// All granular permissions used throughout the OneFellowship app.
///
/// Each value maps to a specific capability that can be granted or denied
/// based on a user's role. See [RolePermissions] for the full matrix.
enum AppPermission {
  // ── General (all roles) ──────────────────────────────────────────────
  viewDashboard,
  viewOwnPayments,
  viewNotifications,
  viewSettings,
  viewConstitution,

  // ── Leadership ───────────────────────────────────────────────────────
  accessAdminPanel,
  manageMembers,
  managePayments,
  manageWallet,
  sendNotifications,
  viewAuditLogs,
  exportData,

  // ── Chairperson-only ────────────────────────────────────────────────
  terminateMembers,
  editMemberRoles,

  // ── Financial ────────────────────────────────────────────────────────
  approveExpenses,

  // ── Feedback & Concerns ──────────────────────────────────────────────
  submitFeedback,
  manageFeedback,
}

/// Central role-based access control (RBAC) matrix for OneFellowship.
///
/// Roles (sourced from the Firestore `role` field):
/// | Role          | Description                        |
/// |---------------|------------------------------------|
/// | `member`      | Regular member (default)           |
/// | `admin`       | Administrative secretary           |
/// | `treasury`    | Treasurer / financial officer      |
/// | `chairperson` | Chairperson / supreme leader       |
///
/// Usage:
/// ```dart
/// if (RolePermissions.hasPermission(user.role, AppPermission.manageWallet)) {
///   // show wallet controls
/// }
/// ```
class RolePermissions {
  RolePermissions._(); // prevent instantiation

  // ── Permission matrix ───────────────────────────────────────────────
  //
  // Each role maps to the *complete* set of permissions it holds.
  // The sets are defined as compile-time constants for performance.

  static const Map<String, Set<AppPermission>> _permissionMatrix = {
    'member': {
      AppPermission.viewDashboard,
      AppPermission.viewOwnPayments,
      AppPermission.viewNotifications,
      AppPermission.viewSettings,
      AppPermission.viewConstitution,
      AppPermission.submitFeedback,
    },
    'treasury': {
      // General
      AppPermission.viewDashboard,
      AppPermission.viewOwnPayments,
      AppPermission.viewNotifications,
      AppPermission.viewSettings,
      AppPermission.viewConstitution,
      AppPermission.submitFeedback,
      // Leadership
      AppPermission.accessAdminPanel,
      AppPermission.managePayments,
      AppPermission.manageWallet,
      AppPermission.exportData,
      // Financial
      AppPermission.approveExpenses,
    },
    'admin': {
      // General
      AppPermission.viewDashboard,
      AppPermission.viewOwnPayments,
      AppPermission.viewNotifications,
      AppPermission.viewSettings,
      AppPermission.viewConstitution,
      AppPermission.submitFeedback,
      // Leadership
      AppPermission.accessAdminPanel,
      AppPermission.manageMembers,
      AppPermission.managePayments,
      AppPermission.sendNotifications,
      AppPermission.viewAuditLogs,
      AppPermission.exportData,
      // Feedback
      AppPermission.manageFeedback,
    },
    'chairperson': {
      // General
      AppPermission.viewDashboard,
      AppPermission.viewOwnPayments,
      AppPermission.viewNotifications,
      AppPermission.viewSettings,
      AppPermission.viewConstitution,
      AppPermission.submitFeedback,
      // Leadership
      AppPermission.accessAdminPanel,
      AppPermission.manageMembers,
      AppPermission.managePayments,
      AppPermission.manageWallet,
      AppPermission.sendNotifications,
      AppPermission.viewAuditLogs,
      AppPermission.exportData,
      // Chairperson-only
      AppPermission.terminateMembers,
      AppPermission.editMemberRoles,
      // Financial
      AppPermission.approveExpenses,
      // Feedback
      AppPermission.manageFeedback,
    },
  };

  // ── Role helpers ────────────────────────────────────────────────────

  /// Normalises a Firestore role string to its canonical lowercase form.
  ///
  /// Returns `'member'` when the input is `null`, empty, or unrecognised.
  static String normalizeRole(String? role) {
    if (role == null || role.trim().isEmpty) return 'member';
    final normalised = role.trim().toLowerCase();
    return _permissionMatrix.containsKey(normalised) ? normalised : 'member';
  }

  // ── Permission checks ──────────────────────────────────────────────

  /// Returns `true` if [role] has been granted [permission].
  static bool hasPermission(String? role, AppPermission permission) {
    final normalised = normalizeRole(role);
    return _permissionMatrix[normalised]?.contains(permission) ?? false;
  }

  /// Returns every [AppPermission] granted to [role].
  static List<AppPermission> getPermissions(String? role) {
    final normalised = normalizeRole(role);
    return _permissionMatrix[normalised]?.toList() ?? [];
  }

  // ── Role classification ─────────────────────────────────────────────

  /// Whether [role] is part of the leadership team
  /// (admin, treasury, or chairperson).
  static bool isLeadership(String? role) {
    final normalised = normalizeRole(role);
    return const {'admin', 'treasury', 'chairperson'}.contains(normalised);
  }

  /// Whether [role] has financial authority (treasury or chairperson).
  static bool isFinancialRole(String? role) {
    final normalised = normalizeRole(role);
    return const {'treasury', 'chairperson'}.contains(normalised);
  }

  // ── Display helpers ─────────────────────────────────────────────────

  /// Human-readable display name for a role.
  static String getRoleDisplayName(String? role) {
    switch (normalizeRole(role)) {
      case 'admin':
        return 'Administrator';
      case 'treasury':
        return 'Treasurer';
      case 'chairperson':
        return 'Chairperson';
      case 'member':
      default:
        return 'Member';
    }
  }

  /// Icon representing a role throughout the app.
  static IconData getRoleIcon(String? role) {
    switch (normalizeRole(role)) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'treasury':
        return Icons.account_balance_wallet;
      case 'chairperson':
        return Icons.stars;
      case 'member':
      default:
        return Icons.person;
    }
  }

  /// Brand colour associated with a role.
  static Color getRoleColor(String? role) {
    switch (normalizeRole(role)) {
      case 'admin':
        return const Color(0xFF1565C0); // blue 800
      case 'treasury':
        return const Color(0xFF2E7D32); // green 800
      case 'chairperson':
        return const Color(0xFFE65100); // orange 900
      case 'member':
      default:
        return const Color(0xFF546E7A); // blueGrey 600
    }
  }
}
