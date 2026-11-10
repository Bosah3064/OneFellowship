import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  static const route = '/admin-audit-logs';

  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'notifications',
    'expenses',
    'payouts',
    'payments',
    'feedback',
    'members',
    'security',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final member = await SupabaseService.fetchCurrentMember();
      final role = (member?['role'] ?? '').toString().toLowerCase();
      if (role != 'admin' && role != 'chairperson') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access restricted: Audit trails are strictly viewable by Administrators only.')),
          );
        }
        return;
      }

      final logs = await SupabaseService.fetchAuditLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audit logs: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    var list = _logs;
    if (_selectedCategory != 'All') {
      list = list.where((log) {
        final cat = (log['category'] ?? '').toString().toLowerCase();
        return cat == _selectedCategory.toLowerCase();
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((log) {
        final action = (log['action'] ?? '').toString().toLowerCase();
        final title = (log['title'] ?? '').toString().toLowerCase();
        final desc = (log['description'] ?? '').toString().toLowerCase();
        final by = (log['performed_by'] ?? '').toString().toLowerCase();
        final role = (log['performed_by_role'] ?? '').toString().toLowerCase();
        return action.contains(q) ||
            title.contains(q) ||
            desc.contains(q) ||
            by.contains(q) ||
            role.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security & Audit Trail',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            Text(
              'Clause 6 & 8 Administrative Logs',
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh Logs',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              bottom: true,
              child: RefreshIndicator(
                onRefresh: _loadLogs,
                child: Column(
                  children: [
                    // Header Banner
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Governance Audit Trail',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Records who sent notifications, approved expenses, and released disbursements.',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Search Input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search by official, action, or note...',
                          hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),

                    // Filter Chips
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i];
                          final isSelected = _selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(
                              cat == 'All' ? 'All Logs' : cat.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Logs Count Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '${filtered.length} Recorded Action${filtered.length == 1 ? '' : 's'}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Logs List View with Safe Bottom Padding
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No audit records found',
                                    style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(16, 4, 16, 28 + MediaQuery.of(context).padding.bottom),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, index) {
                                final log = filtered[index];
                                return _buildAuditCard(log);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> log) {
    final action = (log['action'] ?? '').toString();
    final title = log['title'] ?? 'System Action';
    final desc = log['description'] ?? '';
    final performedBy = log['performed_by'] ?? 'System';
    final performedByRole = log['performed_by_role'] ?? 'Official';
    final dateStr = log['created_at']?.toString() ?? '';
    final category = (log['category'] ?? 'general').toString().toLowerCase();

    Color badgeColor = AppColors.primary;
    IconData icon = Icons.info_outline_rounded;

    if (action.contains('NOTIFICATION')) {
      badgeColor = const Color(0xFF2563EB);
      icon = Icons.mark_email_read_rounded;
    } else if (action.contains('EXPENSE_APPROVED')) {
      badgeColor = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (action.contains('EXPENSE_REJECTED')) {
      badgeColor = AppColors.danger;
      icon = Icons.cancel_rounded;
    } else if (action.contains('PAYOUT')) {
      badgeColor = const Color(0xFFD97706);
      icon = Icons.payments_rounded;
    } else if (action.contains('RECORD')) {
      badgeColor = const Color(0xFF0D9488);
      icon = Icons.receipt_long_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Action Badge + Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      '${category.toUpperCase()} • ${action.replaceAll('_', ' ')}',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTimestamp(dateStr),
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            desc,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Performed by footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Action By: ',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                ),
                Expanded(
                  child: Text(
                    '$performedBy ($performedByRole)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} $h:$m';
    } catch (_) {
      return isoString;
    }
  }
}
