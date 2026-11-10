import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'offline_cache_service.dart';

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

  static Map<String, dynamic>? _cachedMemberDoc;

  /// Fast login: authenticates and pipelines member doc retrieval in one step
  static Future<Map<String, dynamic>?> signIn(String email, String password) async {
    await init();
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) return null;

    // Background asynchronous login timestamp update (does not block UI)
    _recordLoginTime().catchError((_) {});

    // Fast pipelined document fetch
    Map<String, dynamic>? memberData;
    try {
      final docRef = _firestore.collection('members').doc(user.uid);
      final doc = await docRef.get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        memberData = {'id': doc.id, ...doc.data()!};
        _cachedMemberDoc = memberData;
        OfflineCacheService.cacheMember(memberData).catchError((_) {});
      } else {
        // Auto-provision if missing
        _ensureMemberDocument(user).catchError((_) {});
      }
    } catch (e) {
      debugPrint('Fast member fetch error: $e');
    }

    return memberData;
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
    _cachedMemberDoc = null;
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

  static Future<Map<String, dynamic>?> fetchCurrentMember({bool forceRefresh = false}) async {
    final u = currentUser;
    if (u == null) return null;

    if (!forceRefresh && _cachedMemberDoc != null && _cachedMemberDoc!['id'] == u.id) {
      return _cachedMemberDoc;
    }

    try {
      final docRef = _firestore.collection('members').doc(u.id);
      final doc = await docRef.get().timeout(const Duration(seconds: 4));
      if (!doc.exists || doc.data() == null) {
        final rawUser = _auth.currentUser;
        if (rawUser != null) {
          await _ensureMemberDocument(rawUser);
          final newDoc = await docRef.get();
          if (newDoc.exists && newDoc.data() != null) {
            final data = {'id': newDoc.id, ...newDoc.data()!};
            _cachedMemberDoc = data;
            OfflineCacheService.cacheMember(data).catchError((_) {});
            return data;
          }
        }
        return null;
      }
      final data = {'id': doc.id, ...doc.data()!};
      _cachedMemberDoc = data;
      OfflineCacheService.cacheMember(data).catchError((_) {});
      return data;
    } catch (e) {
      debugPrint('fetchCurrentMember error: $e');
      if (_cachedMemberDoc != null && _cachedMemberDoc!['id'] == u.id) {
        return _cachedMemberDoc;
      }
      return await OfflineCacheService.getCachedMember();
    }
  }

  static bool isMemberDataComplete(Map<String, dynamic>? data) {
    if (data == null) return false;
    final formDetails = (data['form_details'] as Map<String, dynamic>?) ?? {};
    if (data['is_profile_complete'] == true || formDetails['is_profile_complete'] == true) {
      return true;
    }
    final phone = (data['phone'] ?? '').toString().trim();
    final idNumber = (formDetails['national_id_number'] ?? formDetails['id_number'] ?? '').toString().trim();
    final branch = (formDetails['branch'] ?? '').toString().trim();
    return phone.isNotEmpty && idNumber.isNotEmpty && branch.isNotEmpty;
  }

  static Future<bool> isProfileComplete(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Check local lock first
    if (prefs.getBool('profile_completed_$userId') == true) {
      return true;
    }

    if (_cachedMemberDoc != null && _cachedMemberDoc!['id'] == userId) {
      final isDone = isMemberDataComplete(_cachedMemberDoc);
      if (isDone) {
        await prefs.setBool('profile_completed_$userId', true);
      }
      return isDone;
    }

    try {
      final doc = await _firestore.collection('members').doc(userId).get().timeout(const Duration(seconds: 4));
      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data()!;
      final isDone = isMemberDataComplete(data);
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

  /// Terminates a member's account, revoking app access and logging audit trail
  static Future<void> terminateMember({
    required String memberId,
    required String reason,
    String? terminatedByName,
    String? terminatedByRole,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    await updateMember(memberId, {
      'status': 'terminated',
      'is_terminated': true,
      'is_active': false,
      'termination_reason': reason,
      'terminated_at': nowStr,
      'terminated_by': terminatedByName ?? currentUser?.displayName ?? 'Admin',
      'terminated_by_role': terminatedByRole ?? 'Administrator',
    });

    await logAuditEvent(
      action: 'MEMBER_TERMINATED',
      title: 'Member Terminated: $memberId',
      description: 'Reason: $reason (Enacted under Article 7 Discipline Policy)',
      category: 'members',
      performedBy: terminatedByName ?? currentUser?.displayName ?? 'Admin',
      performedById: currentUser?.id,
      performedByRole: terminatedByRole ?? 'Administrator',
      metadata: {
        'member_id': memberId,
        'termination_reason': reason,
        'terminated_at': nowStr,
      },
    );
  }

  /// Reinstates a terminated member back to Active status
  static Future<void> reinstateMember({
    required String memberId,
    String? reinstatedByName,
    String? reinstatedByRole,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    await updateMember(memberId, {
      'status': 'active',
      'is_terminated': false,
      'is_active': true,
      'reinstated_at': nowStr,
      'reinstated_by': reinstatedByName ?? currentUser?.displayName ?? 'Admin',
      'reinstated_by_role': reinstatedByRole ?? 'Administrator',
    });

    await logAuditEvent(
      action: 'MEMBER_REINSTATED',
      title: 'Member Reinstated: $memberId',
      description: 'Membership restored to Active status by ${reinstatedByName ?? 'Admin'}',
      category: 'members',
      performedBy: reinstatedByName ?? currentUser?.displayName ?? 'Admin',
      performedById: currentUser?.id,
      performedByRole: reinstatedByRole ?? 'Administrator',
      metadata: {
        'member_id': memberId,
        'reinstated_at': nowStr,
      },
    );
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
    final now = DateTime.now().toIso8601String();
    final pBy = data['recorded_by_name'] ?? currentUser?.displayName ?? 'Admin';
    final pRole = data['recorded_by_role'] ?? 'Leadership Official';

    final payload = {
      'id': docRef.id,
      ...data,
      'recorded_by_name': pBy,
      'recorded_by_role': pRole,
      'recorded_by_id': currentUser?.id,
      if (!data.containsKey('created_at')) 'created_at': now,
      if (!data.containsKey('expense_date')) 'expense_date': now.split('T')[0],
    };
    await docRef.set(payload);

    await logAuditEvent(
      action: 'EXPENSE_RECORDED',
      title: 'Expense Recorded: KES ${data['amount']}',
      description: '${data['description'] ?? 'No notes'} (${data['type'] ?? 'expense'}) - Recorded by $pBy ($pRole)',
      category: 'expenses',
      performedBy: pBy.toString(),
      performedById: currentUser?.id,
      performedByRole: pRole.toString(),
      metadata: {
        'amount': data['amount'],
        'type': data['type'],
        'status': data['status'] ?? 'pending',
        'recorded_by_name': pBy,
        'recorded_by_role': pRole,
        'expense_date': payload['expense_date'],
      },
    );

    // Auto-notify all 3 approving leaders (Chairperson, Treasurer, Admin) of pending disbursement
    notifyExpenseApprovers(
      expenseId: docRef.id,
      description: data['description']?.toString() ?? 'Expense',
      amount: num.tryParse(data['amount']?.toString() ?? '0')?.toDouble() ?? 0.0,
      currentApprovalCount: 0,
      reason: 'new_expense',
    ).catchError((_) => 0);
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

    final approverName = auditTrail?['approved_by_name'] ?? currentUser?.displayName ?? 'Official';
    final approverRole = auditTrail?['approver_role'] ?? auditTrail?['authorized_role'] ?? 'Leadership Official';

    await logAuditEvent(
      action: status == 'approved' ? 'EXPENSE_APPROVED' : 'EXPENSE_REJECTED',
      title: 'Expense ${status.toUpperCase()}: ID $id',
      description: 'Status updated to ${status.toUpperCase()} by $approverName ($approverRole)',
      category: 'expenses',
      performedBy: approverName.toString(),
      performedById: auditTrail?['approved_by_id'] ?? currentUser?.id,
      performedByRole: approverRole.toString(),
      metadata: {
        'expense_id': id,
        'status': status,
        if (auditTrail != null) ...auditTrail,
      },
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
    final now = DateTime.now().toIso8601String();
    final u = currentUser;
    final logId = 'log_${DateTime.now().millisecondsSinceEpoch}';

    final logData = <String, dynamic>{
      'id': logId,
      'action': action,
      'title': title,
      'description': description,
      'category': category,
      'performed_by': performedBy ?? u?.displayName ?? 'Admin Official',
      'performed_by_id': performedById ?? u?.id ?? 'admin',
      'performed_by_role': performedByRole ?? 'Official',
      'metadata': metadata ?? {},
      'created_at': now,
    };

    // 1. Cache to local storage immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRaw = prefs.getStringList('offline_audit_logs_v1') ?? [];
      cachedRaw.insert(0, jsonEncode(logData));
      if (cachedRaw.length > 300) cachedRaw.removeLast();
      await prefs.setStringList('offline_audit_logs_v1', cachedRaw);
    } catch (e) {
      debugPrint('Error caching audit log to SharedPreferences: $e');
    }

    // 2. Write to Firestore
    try {
      final docRef = _firestore.collection('audit_logs').doc();
      logData['id'] = docRef.id;
      await docRef.set(logData);
    } catch (e) {
      debugPrint('logAuditEvent firestore error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAuditLogs() async {
    final Map<String, Map<String, dynamic>> combined = {};

    // 1. Fetch from Firestore audit_logs collection
    try {
      final snap = await _firestore.collection('audit_logs').get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final key = '${d['action']}_${d['title']}_${d['created_at']}';
        combined[key] = {'id': doc.id, ...d};
      }
    } catch (e) {
      debugPrint('fetchAuditLogs (firestore audit_logs) error: $e');
    }

    // 2. Fetch from local cached audit logs
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRaw = prefs.getStringList('offline_audit_logs_v1') ?? [];
      for (final raw in cachedRaw) {
        try {
          final d = jsonDecode(raw) as Map<String, dynamic>;
          final key = '${d['action']}_${d['title']}_${d['created_at']}';
          if (!combined.containsKey(key)) {
            combined[key] = d;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('fetchAuditLogs (local cache) error: $e');
    }

    // 3. Fallback/Backfill: Synthesize from Firestore 'notifications' collection
    try {
      final notifSnap = await _firestore.collection('notifications').get();
      for (final doc in notifSnap.docs) {
        final nd = doc.data();
        final title = (nd['title'] ?? 'Announcement').toString();
        final msg = (nd['message'] ?? '').toString();
        final by = nd['sender_name'] ?? nd['created_by'] ?? 'Admin Official';
        final role = nd['sender_role'] ?? 'Authority / Leader';
        final time = (nd['created_at'] ?? '').toString();
        final key = 'NOTIFICATION_SENT_${title}_$time';

        if (!combined.containsKey(key)) {
          combined[key] = {
            'id': 'notif_${doc.id}',
            'action': 'NOTIFICATION_SENT',
            'title': 'Dispatched Notification: "$title"',
            'description': msg.isNotEmpty ? msg : 'Broadcast notification sent to members.',
            'category': 'notifications',
            'performed_by': by,
            'performed_by_id': nd['sender_id'] ?? 'admin',
            'performed_by_role': role,
            'created_at': time.isNotEmpty ? time : DateTime.now().toIso8601String(),
            'metadata': {
              'type': nd['type'] ?? 'info',
              'recipient': nd['recipient'] ?? nd['member_id'] ?? 'All',
            },
          };
        }
      }
    } catch (e) {
      debugPrint('fetchAuditLogs (synthesize notifications) error: $e');
    }

    // 4. Fallback/Backfill: Synthesize from Firestore 'organization_expenses' collection
    try {
      final expSnap = await _firestore.collection('organization_expenses').get();
      for (final doc in expSnap.docs) {
        final ed = doc.data();
        final amt = ed['amount'] ?? 0;
        final type = (ed['type'] ?? 'expense').toString();
        final desc = (ed['description'] ?? 'Expense').toString();
        final status = (ed['status'] ?? 'pending').toString().toLowerCase();
        final by = ed['recorded_by_name'] ?? ed['approved_by_name'] ?? ed['added_by_name'] ?? 'Treasury / Chairperson';
        final role = ed['recorded_by_role'] ?? ed['authorized_role'] ?? 'Treasurer / Leadership';
        final time = (ed['created_at'] ?? ed['expense_date'] ?? '').toString();
        final action = status == 'approved' ? 'EXPENSE_APPROVED' : 'EXPENSE_RECORDED';
        final key = '${action}_${amt}_$desc';

        if (!combined.containsKey(key)) {
          combined[key] = {
            'id': 'exp_${doc.id}',
            'action': action,
            'title': 'Expense Recorded: KES $amt ($type)',
            'description': '$desc • Status: ${status.toUpperCase()}',
            'category': 'expenses',
            'performed_by': by,
            'performed_by_id': ed['recorded_by_id'] ?? ed['added_by'] ?? 'admin',
            'performed_by_role': role,
            'created_at': time.isNotEmpty ? time : DateTime.now().toIso8601String(),
            'metadata': {
              'amount': amt,
              'type': type,
              'status': status,
            },
          };
        }
      }
    } catch (e) {
      debugPrint('fetchAuditLogs (synthesize expenses) error: $e');
    }

    final list = combined.values.toList();
    list.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    return list;
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

  // ─── Feedback & Concerns ───────────────────────────────────────

  /// Submit feedback/concern from a member.
  static Future<void> submitFeedback({
    required String category,
    required String subject,
    required String message,
  }) async {
    final u = currentUser;
    final member = await fetchCurrentMember();
    final now = DateTime.now().toIso8601String();
    final docRef = _firestore.collection('feedback').doc();

    await docRef.set({
      'id': docRef.id,
      'member_id': u?.id ?? '',
      'member_name': member?['full_name'] ?? u?.displayName ?? 'Anonymous',
      'member_email': member?['email'] ?? u?.email ?? '',
      'member_phone': member?['phone'] ?? '',
      'category': category,
      'subject': subject,
      'message': message,
      'status': 'open', // open, in_review, resolved, closed
      'admin_response': null,
      'responded_by': null,
      'responded_at': null,
      'created_at': now,
      'updated_at': now,
    });

    await logAuditEvent(
      action: 'FEEDBACK_SUBMITTED',
      title: 'New Feedback: $subject',
      description: '${member?['full_name'] ?? 'Member'} submitted a $category: $subject',
      category: 'feedback',
      performedBy: member?['full_name']?.toString() ?? 'Member',
      performedById: u?.id,
    );
  }

  /// Fetch all feedback (admin view).
  static Future<List<Map<String, dynamic>>> fetchAllFeedback() async {
    final snap = await _firestore.collection('feedback').get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    return list;
  }

  /// Fetch feedback submitted by the current user.
  static Future<List<Map<String, dynamic>>> fetchMyFeedback() async {
    final u = currentUser;
    if (u == null) return [];
    final snap = await _firestore.collection('feedback')
        .where('member_id', isEqualTo: u.id)
        .get();
    final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    list.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    return list;
  }

  /// Admin responds to feedback.
  static Future<void> respondToFeedback({
    required String feedbackId,
    required String response,
    required String newStatus,
  }) async {
    final u = currentUser;
    final member = await fetchCurrentMember();
    final now = DateTime.now().toIso8601String();

    await _firestore.collection('feedback').doc(feedbackId).update({
      'admin_response': response,
      'responded_by': member?['full_name'] ?? u?.displayName ?? 'Admin',
      'responded_by_id': u?.id,
      'responded_by_role': member?['role'] ?? 'admin',
      'responded_at': now,
      'status': newStatus,
      'updated_at': now,
    });

    await logAuditEvent(
      action: 'FEEDBACK_RESPONDED',
      title: 'Feedback Responded: $feedbackId',
      description: '${member?['full_name'] ?? 'Admin'} responded to feedback and set status to $newStatus',
      category: 'feedback',
      performedBy: member?['full_name']?.toString() ?? 'Admin',
      performedById: u?.id,
      performedByRole: member?['role']?.toString() ?? 'admin',
    );
  }

  // ─── Multi-Approval for Expenses (3 Leaders) ──────────────────

  /// Add an approval signature to an expense. Returns the updated approvals list.
  static Future<List<Map<String, dynamic>>> addExpenseApproval({
    required String expenseId,
    required String approverRole,
  }) async {
    final u = currentUser;
    final member = await fetchCurrentMember();
    final approverName = member?['full_name'] ?? u?.displayName ?? 'Official';
    final approverId = u?.id ?? '';
    final now = DateTime.now().toIso8601String();

    final docRef = _firestore.collection('organization_expenses').doc(expenseId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Expense not found');

    final data = doc.data()!;
    final List<dynamic> existingApprovals = data['approvals'] ?? [];

    // Check if this person already approved
    for (final a in existingApprovals) {
      if (a is Map && a['approver_id'] == approverId) {
        throw Exception('You have already signed this expense');
      }
    }

    final newApproval = {
      'approver_id': approverId,
      'approver_name': approverName,
      'approver_role': approverRole,
      'approved_at': now,
      'fraud_policy_acknowledged': true,
    };

    existingApprovals.add(newApproval);

    final updateData = <String, dynamic>{
      'approvals': existingApprovals,
      'approval_count': existingApprovals.length,
      'last_approval_at': now,
    };

    // If 3 approvals reached, mark as fully approved
    if (existingApprovals.length >= 3) {
      updateData['status'] = 'approved';
      updateData['status_updated_at'] = now;
      updateData['approved_by_name'] = existingApprovals.map((a) => a['approver_name']).join(', ');
      updateData['authorized_role'] = existingApprovals.map((a) => a['approver_role']).join(', ');
    }

    await docRef.update(updateData);

    await logAuditEvent(
      action: existingApprovals.length >= 3 ? 'EXPENSE_FULLY_APPROVED' : 'EXPENSE_APPROVAL_ADDED',
      title: existingApprovals.length >= 3
          ? 'Expense FULLY APPROVED (3/3): $expenseId'
          : 'Expense Approval ${existingApprovals.length}/3: $expenseId',
      description: '$approverName ($approverRole) signed approval ${existingApprovals.length}/3',
      category: 'expenses',
      performedBy: approverName,
      performedById: approverId,
      performedByRole: approverRole,
      metadata: {
        'expense_id': expenseId,
        'approval_count': existingApprovals.length,
        'approver_role': approverRole,
        'is_fully_approved': existingApprovals.length >= 3,
      },
    );

    // If still awaiting more signatures, notify remaining approvers
    if (existingApprovals.length < 3) {
      notifyExpenseApprovers(
        expenseId: expenseId,
        description: data['description']?.toString() ?? 'Expense',
        amount: num.tryParse(data['amount']?.toString() ?? '0')?.toDouble() ?? 0.0,
        currentApprovalCount: existingApprovals.length,
        reason: 'reminder',
      ).catchError((_) => 0);
    }

    return existingApprovals.cast<Map<String, dynamic>>();
  }

  /// Broadcasts an alert/reminder notification to all officials who hold approval authority
  /// (Admin, Treasury, Chairperson) regarding a pending expense disbursement.
  static Future<int> notifyExpenseApprovers({
    required String expenseId,
    required String description,
    required double amount,
    int currentApprovalCount = 0,
    String? reason, // 'new_expense' or 'reminder'
  }) async {
    try {
      final members = await adminFetchAllMembers();
      final leaders = members.where((m) {
        final r = (m['role'] ?? '').toString().toLowerCase();
        return r == 'admin' || r == 'treasury' || r == 'chairperson';
      }).toList();

      if (leaders.isEmpty) return 0;

      final leaderIds = leaders.map((l) => l['id'].toString()).toList();
      final isReminder = reason == 'reminder';
      final title = isReminder
          ? '🔔 REMINDER: Leadership Approval Needed ($currentApprovalCount/3)'
          : '⚠️ DISBURSEMENT ACTION: 3 Signatures Required ($currentApprovalCount/3)';
      final message = 'Disbursement of KES ${amount.toStringAsFixed(0)} for "$description" requires 3 leadership signatures ($currentApprovalCount/3 signed). Please review and sign.';

      final u = currentUser;
      final currentMember = await fetchCurrentMember();
      final sName = currentMember?['full_name'] ?? u?.displayName ?? 'Leadership';
      final sRole = currentMember?['role'] ?? 'Official';

      await adminSendNotification(
        memberIds: leaderIds,
        title: title,
        message: message,
        type: 'alert',
        senderName: sName,
        senderId: u?.id,
        senderRole: sRole,
      );

      return leaderIds.length;
    } catch (e) {
      debugPrint('notifyExpenseApprovers error: $e');
      return 0;
    }
  }
}
