import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';
import '../services/offline_cache_service.dart';

class NotificationsScreen extends StatefulWidget {
  static const route = '/notifications';
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        final notifs = await SupabaseService.fetchNotifications(user.id);
        // Cache for offline use
        await OfflineCacheService.cacheNotifications(notifs);
        if (mounted) {
          setState(() {
            _notifications = notifs;
            _isLoading = false;
            _isOffline = false;
          });
        }
      }
    } catch (e) {
      // Offline fallback
      try {
        final cached = await OfflineCacheService.getCachedNotifications();
        if (mounted) {
          setState(() {
            _notifications = cached;
            _isLoading = false;
            _isOffline = true;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await SupabaseService.markNotificationRead(id);
      _loadNotifications();
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      for (final n in _notifications) {
        if (n['is_read'] == false) {
          await SupabaseService.markNotificationRead(n['id'].toString());
        }
      }
      _loadNotifications();
    } catch (_) {}
  }

  IconData _iconFor(String type, String title, String message) {
    final t = title.toLowerCase();
    final m = message.toLowerCase();
    
    if (t.contains('approved') || m.contains('approved') || t.contains('✅')) return Icons.verified_rounded;
    if (t.contains('pending') || m.contains('pending')) return Icons.hourglass_empty_rounded;
    if (t.contains('recorded') || m.contains('recorded')) return Icons.receipt_long_rounded;
    if (t.contains('rejected') || m.contains('failed')) return Icons.error_outline_rounded;
    if (m.contains('kes')) return Icons.account_balance_wallet_rounded;
    
    switch (type) {
      case 'payment': return Icons.account_balance_wallet_rounded;
      case 'approval': return Icons.verified_rounded;
      case 'system': return Icons.info_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  Color _colorFor(String type, String title, String message) {
    final t = title.toLowerCase();
    final m = message.toLowerCase();
    
    if (t.contains('approved') || m.contains('approved') || t.contains('✅')) return AppColors.success;
    if (t.contains('pending') || m.contains('pending')) return Colors.orange.shade600;
    if (t.contains('recorded') || m.contains('recorded')) return const Color(0xFF3B82F6); // Bright Blue
    if (t.contains('rejected') || m.contains('failed')) return Colors.red.shade600;
    if (m.contains('kes')) return AppColors.primary;

    switch (type) {
      case 'payment': return AppColors.primary;
      case 'approval': return AppColors.success;
      case 'system': return Colors.purple.shade600;
      default: return AppColors.primary;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
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
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (_notifications.any((n) => n['is_read'] == false))
                      GestureDetector(
                        onTap: _markAllAsRead,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Read All',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (_isOffline)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Color(0xFFB8860B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Viewing cached notifications',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF856404)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_notifications.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will receive notifications when\npayments are recorded or approved.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final n = _notifications[index];
                  final isRead = n['is_read'] == true;
                  final type = (n['type'] ?? 'info').toString();
                  final title = n['title']?.toString() ?? 'Notification';
                  final message = n['message']?.toString() ?? '';
                  final time = _timeAgo(n['created_at']?.toString());

                  return Padding(
                    padding: EdgeInsets.fromLTRB(20, index == 0 ? 20 : 0, 20, 14),
                    child: GestureDetector(
                      onTap: () {
                        if (!isRead) _markAsRead(n['id'].toString());
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isRead ? const Color(0xFFF3F4F6) : AppColors.primary.withOpacity(0.3),
                            width: isRead ? 1 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isRead ? Colors.black.withOpacity(0.02) : AppColors.primary.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isRead ? _colorFor(type, title, message).withOpacity(0.08) : _colorFor(type, title, message).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(_iconFor(type, title, message), color: _colorFor(type, title, message), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: GoogleFonts.outfit(
                                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                            fontSize: 16,
                                            color: isRead ? AppColors.textPrimary.withOpacity(0.8) : AppColors.textPrimary,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text('NEW', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    message,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: isRead ? AppColors.textSecondary : const Color(0xFF374151),
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted.withOpacity(0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        time,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _notifications.length,
              ),
            ),
        ],
      ),
    );
  }
}
