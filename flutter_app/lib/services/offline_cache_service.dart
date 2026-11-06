import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides offline caching for the app.
/// When the user has internet, data is fetched from Supabase and cached locally.
/// When offline ("Free Mode"), cached data is served instead.
class OfflineCacheService {
  static const _keyMember = 'cache_member';
  static const _keyPayments = 'cache_payments';
  static const _keyNotifications = 'cache_notifications';

  // ─── Member ─────────────────────────────────────────────────────────

  static Future<void> cacheMember(Map<String, dynamic> member) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMember, jsonEncode(member));
  }

  static Future<Map<String, dynamic>?> getCachedMember() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMember);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  // ─── Payments ───────────────────────────────────────────────────────

  static Future<void> cachePayments(List<Map<String, dynamic>> payments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPayments, jsonEncode(payments));
  }

  static Future<List<Map<String, dynamic>>> getCachedPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPayments);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── Notifications ─────────────────────────────────────────────────

  static Future<void> cacheNotifications(List<Map<String, dynamic>> notifs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotifications, jsonEncode(notifs));
  }

  static Future<List<Map<String, dynamic>>> getCachedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyNotifications);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── Clear ──────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMember);
    await prefs.remove(_keyPayments);
    await prefs.remove(_keyNotifications);
  }
}
