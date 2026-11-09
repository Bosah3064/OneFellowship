import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

/// User wrapper to provide backwards compatibility with screens
class AppUser {
  final String id;
  final String? email;
  final String? displayName;
  final Map<String, dynamic>? userMetadata;

  AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.userMetadata,
  });

  factory AppUser.fromFirebase(fb_auth.User firebaseUser) {
    final name = firebaseUser.displayName ?? '';
    return AppUser(
      id: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: name,
      userMetadata: {
        'full_name': name,
        'email': firebaseUser.email ?? '',
      },
    );
  }
}

/// Firebase Backend Service for OneFellowship Mobile App
class SupabaseService {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static fb_auth.FirebaseAuth get _auth => fb_auth.FirebaseAuth.instance;
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static Future<void> init({String? url, String? anonKey}) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase init error: $e');
      _initialized = true;
    }
  }

  // ─── Auth ───────────────────────────────────────────────────────────

  static AppUser? get currentUser {
    final u = _auth.currentUser;
    if (u == null) return null;
    return AppUser.fromFirebase(u);
  }

  static Future<void> _recordLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_login_time', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> isSessionValid() async {
    if (_auth.currentUser == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastLoginMs = prefs.getInt('last_login_time');
    if (lastLoginMs == null) return false;

    final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMs);
    final diff = DateTime.now().difference(lastLogin);
    // If it's been more than 7 days, sign out
    if (diff.inDays >= 7) {
      await signOut();
      return false;
    }
    return true;
  }

  static Future<void> signIn(String email, String password) async {
    await init();
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user != null) {
      await _ensureMemberDocument(user);
    }
    await _recordLoginTime();
  }

  static Future<void> _ensureMemberDocument(fb_auth.User user) async {
    try {
      final docRef = _firestore.collection('members').doc(user.uid);
      final doc = await docRef.get();
      final cleanEmail = user.email?.trim() ?? '';
      if (!doc.exists || doc.data() == null) {
        final displayName = (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : (cleanEmail.isNotEmpty ? cleanEmail.split('@').first : 'Member');
        await docRef.set({
          'id': user.uid,
          'full_name': displayName,
          'email': cleanEmail,
          'phone': user.phoneNumber ?? '',
          'role': (cleanEmail == 'bosah3064@gmail.com' || cleanEmail == 'lame3064@gmail.com') ? 'admin' : 'member',
          'status': 'active',
          'requires_password_reset': false,
          'created_at': DateTime.now().toIso8601String(),
          'join_date': DateTime.now().toIso8601String(),
          'form_details': <String, dynamic>{},
        }, SetOptions(merge: true));
        debugPrint('Auto-provisioned Firestore member doc for ${user.uid}');
      }
    } catch (e) {
      debugPrint('Error ensuring member document: $e');
    }
  }

  static Future<void> signUp(String fullName, String email, String password) async {
    await init();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final u = cred.user;
    if (u != null) {
      try {
        await u.updateDisplayName(fullName);
      } catch (_) {}

      final cleanEmail = email.trim();
      // Write member document in Cloud Firestore
      await _firestore.collection('members').doc(u.uid).set({
        'id': u.uid,
        'full_name': fullName.trim(),
        'email': cleanEmail,
        'phone': '',
        'role': (cleanEmail == 'bosah3064@gmail.com' || cleanEmail == 'lame3064@gmail.com') ? 'admin' : 'member',
        'status': 'active',
        'requires_password_reset': false,
        'created_at': DateTime.now().toIso8601String(),
        'join_date': DateTime.now().toIso8601String(),
        'form_details': <String, dynamic>{},
      }, SetOptions(merge: true));

      await _recordLoginTime();
    } else {
      throw Exception('Sign up failed');
    }
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_login_time');
    await _auth.signOut();
  }

  static Future<void> resetPasswordForEmail(String email) async {
    await init();
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> updateUserPassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  // ─── Members ────────────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> membersStream() {
    return _firestore
        .collection('members')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  static Future<List<Map<String, dynamic>>> fetchMembers() async {
    final snap = await _firestore.collection('members').get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (a['full_name'] ?? '').toString().compareTo((b['full_name'] ?? '').toString()));
    return list;
  }

  static Future<Map<String, dynamic>?> fetchCurrentMember() async {
    final u = currentUser;
    if (u == null) return null;
    try {
      final docRef = _firestore.collection('members').doc(u.id);
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) {
        final rawUser = _auth.currentUser;
        if (rawUser != null) {
          await _ensureMemberDocument(rawUser);
          final newDoc = await docRef.get();
          if (newDoc.exists && newDoc.data() != null) {
            return {'id': newDoc.id, ...newDoc.data()!};
          }
        }
        return null;
      }
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('fetchCurrentMember error: $e');
      return null;
    }
  }

  static Future<bool> isProfileComplete(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Check local lock first
    if (prefs.getBool('profile_completed_$userId') == true) {
      return true;
    }

    try {
      final doc = await _firestore.collection('members').doc(userId).get();
      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data()!;
      final formDetails = (data['form_details'] as Map<String, dynamic>?) ?? {};

      // Explicit flag
      if (data['is_profile_complete'] == true || formDetails['is_profile_complete'] == true) {
        await prefs.setBool('profile_completed_$userId', true);
        return true;
      }

      final phone = (data['phone'] ?? '').toString().trim();
      final idNumber = (formDetails['national_id_number'] ?? formDetails['id_number'] ?? '').toString().trim();
      final branch = (formDetails['branch'] ?? '').toString().trim();

      final isDone = phone.isNotEmpty && idNumber.isNotEmpty && branch.isNotEmpty;
      if (isDone) {
        await prefs.setBool('profile_completed_$userId', true);
      }
      return isDone;
    } catch (_) {
      return prefs.getBool('profile_completed_$userId') ?? false;
    }
  }

  static Future<void> saveProfileDetails(
    String userId, {
    required String phone,
    required Map<String, dynamic> formDetails,
    String? fullName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Lock completion locally so no redirection ever happens again
    await prefs.setBool('profile_completed_$userId', true);

    final mergedFormDetails = {
      ...formDetails,
      'is_profile_complete': true,
      'completed_at': DateTime.now().toIso8601String(),
    };

    final updateData = <String, dynamic>{
      'phone': phone.trim(),
      'is_profile_complete': true,
      'form_details': mergedFormDetails,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null && fullName.trim().isNotEmpty) {
      updateData['full_name'] = fullName.trim();
      try {
        await _auth.currentUser?.updateDisplayName(fullName.trim());
      } catch (_) {}
    }
    await _firestore.collection('members').doc(userId).set(updateData, SetOptions(merge: true));
  }

  static Future<void> addMember(Map<String, dynamic> data) async {
    final id = data['id'] ?? _firestore.collection('members').doc().id;
    data['id'] = id;
    await _firestore.collection('members').doc(id).set(data, SetOptions(merge: true));
  }

  static Future<void> updateMember(String id, Map<String, dynamic> changes) async {
    await _firestore.collection('members').doc(id).set(changes, SetOptions(merge: true));
  }

  // ─── Card Theme ─────────────────────────────────────────────────────

  static Future<void> updateCardTheme(int themeIndex) async {
    final u = currentUser;
    if (u == null) throw Exception('No authenticated user');

    final doc = await _firestore.collection('members').doc(u.id).get();
    final existing = (doc.data()?['form_details'] as Map<String, dynamic>?) ?? {};
    final merged = {...existing, 'card_theme': themeIndex};

    await _firestore.collection('members').doc(u.id).set({
      'form_details': merged,
    }, SetOptions(merge: true));
  }

  // ─── Payments ───────────────────────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> paymentsStream() {
    return _firestore
        .collection('payments')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  static Future<List<Map<String, dynamic>>> fetchPayments() async {
    final snap = await _firestore.collection('payments').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchMemberPayments(String memberId) async {
    final snap = await _firestore
        .collection('payments')
        .where('member_id', isEqualTo: memberId)
        .get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (b['payment_date'] ?? '').toString().compareTo((a['payment_date'] ?? '').toString()));
    return list;
  }

  static Future<void> updatePayment(String id, Map<String, dynamic> changes) async {
    await _firestore.collection('payments').doc(id).set(changes, SetOptions(merge: true));
  }

  // ─── Notifications ─────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchNotifications(String memberId) async {
    final snap = await _firestore
        .collection('notifications')
        .where('member_id', isEqualTo: memberId)
        .get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    return list;
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'is_read': true});
  }

  static Future<int> countUnreadNotifications(String memberId) async {
    final snap = await _firestore
        .collection('notifications')
        .where('member_id', isEqualTo: memberId)
        .where('is_read', isEqualTo: false)
        .count()
        .get();
    return snap.count ?? 0;
  }

  static Stream<List<Map<String, dynamic>>> notificationsStream(String memberId) {
    return _firestore
        .collection('notifications')
        .where('member_id', isEqualTo: memberId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ─── Admin Tools ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminFetchAllMembers() async {
    return fetchMembers();
  }

  static Future<void> adminUpdateMember(String id, Map<String, dynamic> data) async {
    await updateMember(id, data);
  }

  static Future<List<Map<String, dynamic>>> adminFetchAllPayments() async {
    final snap = await _firestore.collection('payments').get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (b['payment_date'] ?? '').toString().compareTo((a['payment_date'] ?? '').toString()));
    return list;
  }

  static Future<void> adminAddPayment(Map<String, dynamic> data) async {
    final docRef = _firestore.collection('payments').doc();
    final id = docRef.id;
    final payload = {
      'id': id,
      ...data,
      if (!data.containsKey('created_at')) 'created_at': DateTime.now().toIso8601String(),
    };
    await docRef.set(payload);
  }

  static Future<void> adminUpdatePayment(String id, Map<String, dynamic> data) async {
    await _firestore.collection('payments').doc(id).set(data, SetOptions(merge: true));
  }

  static Future<void> adminDeletePayment(String id) async {
    await _firestore.collection('payments').doc(id).delete();
  }

  static Future<void> adminSendNotification({
    required List<String> memberIds,
    required String title,
    required String message,
    String type = 'info',
    String? senderName,
    String? senderId,
    String? senderRole,
  }) async {
    if (memberIds.isEmpty) return;
    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();
    final sName = senderName ?? currentUser?.displayName ?? 'Admin';
    final sId = senderId ?? currentUser?.id ?? 'admin';
    final sRole = senderRole ?? 'Administrator';

    for (final id in memberIds) {
      final docRef = _firestore.collection('notifications').doc();
      batch.set(docRef, {
        'id': docRef.id,
        'member_id': id,
        'title': title,
        'message': message,
        'type': type,
        'is_read': false,
        'sender_id': sId,
        'sender_name': sName,
        'sender_role': sRole,
        'created_at': now,
      });
    }
    await batch.commit();

    // Log to Audit Trail
    await logAuditEvent(
      action: 'NOTIFICATION_SENT',
      title: 'Dispatched Notification: "$title"',
      description: 'Sent to ${memberIds.length} member(s): "$message"',
      category: 'notifications',
      performedBy: sName,
      performedById: sId,
      performedByRole: sRole,
      metadata: {
        'recipient_count': memberIds.length,
        'type': type,
        'notification_title': title,
      },
    );
  }

  // ─── Admin Wallet (Expenses) ──────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminFetchAllExpenses() async {
    final snap = await _firestore.collection('organization_expenses').get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (b['expense_date'] ?? '').toString().compareTo((a['expense_date'] ?? '').toString()));
    return list;
  }

  static Future<void> adminAddExpense(Map<String, dynamic> data) async {
    final docRef = _firestore.collection('organization_expenses').doc();
    final payload = {
      'id': docRef.id,
      ...data,
      if (!data.containsKey('created_at')) 'created_at': DateTime.now().toIso8601String(),
    };
    await docRef.set(payload);

    await logAuditEvent(
      action: 'EXPENSE_RECORDED',
      title: 'Expense Recorded: KES ${data['amount']}',
      description: '${data['description'] ?? 'No notes'} (${data['type'] ?? 'expense'})',
      category: 'expenses',
      performedBy: currentUser?.displayName ?? 'Admin',
      performedById: currentUser?.id,
      metadata: {'amount': data['amount'], 'type': data['type']},
    );
  }

  static Future<void> adminUpdateExpenseStatus(String id, String status, {Map<String, dynamic>? auditTrail}) async {
    final updateData = <String, dynamic>{
      'status': status,
      'status_updated_at': DateTime.now().toIso8601String(),
    };
    if (auditTrail != null) {
      updateData.addAll(auditTrail);
    }
    await _firestore.collection('organization_expenses').doc(id).update(updateData);

    await logAuditEvent(
      action: status == 'approved' ? 'EXPENSE_APPROVED' : 'EXPENSE_REJECTED',
      title: 'Expense $status: ID $id',
      description: 'Status changed to $status by ${auditTrail?['approver_role'] ?? 'Official'}',
      category: 'expenses',
      performedBy: auditTrail?['approved_by_name'] ?? currentUser?.displayName ?? 'Official',
      performedById: auditTrail?['approved_by_id'] ?? currentUser?.id,
      performedByRole: auditTrail?['approver_role']?.toString(),
      metadata: auditTrail ?? {},
    );
  }

  // ─── Security & Audit Logs ────────────────────────────────────

  static Future<void> logAuditEvent({
    required String action,
    required String title,
    required String description,
    required String category, // 'notifications', 'expenses', 'payouts', 'members', 'security'
    String? performedBy,
    String? performedById,
    String? performedByRole,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final u = currentUser;
      final docRef = _firestore.collection('audit_logs').doc();
      final now = DateTime.now().toIso8601String();
      await docRef.set({
        'id': docRef.id,
        'action': action,
        'title': title,
        'description': description,
        'category': category,
        'performed_by': performedBy ?? u?.displayName ?? 'Admin',
        'performed_by_id': performedById ?? u?.id ?? 'admin',
        'performed_by_role': performedByRole ?? 'Official',
        'metadata': metadata ?? {},
        'created_at': now,
      });
    } catch (e) {
      debugPrint('logAuditEvent error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAuditLogs() async {
    try {
      final snap = await _firestore.collection('audit_logs').get();
      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      return list;
    } catch (e) {
      debugPrint('fetchAuditLogs error: $e');
      return [];
    }
  }

  // ─── Admin Password Reset ─────────────────────────────────────

  static Future<void> adminResetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    // Flag member as requiring password reset
    await _firestore.collection('members').doc(userId).set({
      'requires_password_reset': true,
    }, SetOptions(merge: true));
  }
}
