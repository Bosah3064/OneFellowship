import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';

class AdminFeedbackScreen extends StatefulWidget {
  static const route = '/admin-feedback';
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allFeedback = [];
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() => _isLoading = true);
    try {
      final feedback = await SupabaseService.fetchAllFeedback();
      if (mounted) setState(() { _allFeedback = feedback; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredFeedback {
    if (_filterStatus == 'all') return _allFeedback;
    return _allFeedback.where((fb) => (fb['status'] ?? 'open').toString().toLowerCase() == _filterStatus).toList();
  }

  int _countByStatus(String status) {
    return _allFeedback.where((fb) => (fb['status'] ?? 'open').toString().toLowerCase() == status).length;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return AppColors.warning;
      case 'in_review': return AppColors.primary;
      case 'resolved': return AppColors.success;
      case 'closed': return AppColors.textMuted;
      default: return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'open': return 'OPEN';
      case 'in_review': return 'IN REVIEW';
      case 'resolved': return 'RESOLVED';
      case 'closed': return 'CLOSED';
      default: return status.toUpperCase();
    }
  }

  String _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'concern': return '🔴';
      case 'complaint': return '⚠️';
      case 'suggestion': return '💡';
      case 'appreciation': return '🌟';
      case 'question': return '❓';
      default: return '📝';
    }
  }

  void _showRespondDialog(Map<String, dynamic> fb) {
    final responseCtrl = TextEditingController(text: fb['admin_response']?.toString() ?? '');
    String newStatus = (fb['status'] ?? 'open').toString().toLowerCase();
    if (newStatus == 'open') newStatus = 'in_review';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.reply_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Respond to Feedback', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('From: ${fb['member_name'] ?? 'Unknown'}',
                          style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original message preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_categoryIcon(fb['category'] ?? ''), style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(fb['subject'] ?? 'No Subject',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(fb['message'] ?? '',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            maxLines: 4, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Update Status', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: ['open', 'in_review', 'resolved', 'closed'].contains(newStatus) ? newStatus : 'in_review',
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('🟡 Open')),
                      DropdownMenuItem(value: 'in_review', child: Text('🔵 In Review')),
                      DropdownMenuItem(value: 'resolved', child: Text('🟢 Resolved')),
                      DropdownMenuItem(value: 'closed', child: Text('⚫ Closed')),
                    ],
                    onChanged: (v) { if (v != null) setD(() => newStatus = v); },
                  ),
                  const SizedBox(height: 14),
                  Text('Your Response', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: responseCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your response to the member...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  if (responseCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please write a response')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  try {
                    await SupabaseService.respondToFeedback(
                      feedbackId: fb['id'],
                      response: responseCtrl.text.trim(),
                      newStatus: newStatus,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Response sent successfully!'), backgroundColor: AppColors.success),
                      );
                      _loadFeedback();
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                label: Text('Send Response', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFeedback;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Member Feedback & Concerns', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Stats row
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      _buildStatChip('All', _allFeedback.length, 'all'),
                      const SizedBox(width: 8),
                      _buildStatChip('Open', _countByStatus('open'), 'open'),
                      const SizedBox(width: 8),
                      _buildStatChip('Review', _countByStatus('in_review'), 'in_review'),
                      const SizedBox(width: 8),
                      _buildStatChip('Resolved', _countByStatus('resolved'), 'resolved'),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('No feedback found',
                                  style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _loadFeedback,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final fb = filtered[index];
                              final status = (fb['status'] ?? 'open').toString();
                              final cat = (fb['category'] ?? '').toString();
                              final dateStr = (fb['created_at'] ?? '').toString();
                              final date = dateStr.length >= 10 ? dateStr.substring(0, 10) : 'Unknown';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                                color: Colors.white,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showRespondDialog(fb),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(_categoryIcon(cat), style: const TextStyle(fontSize: 20)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fb['subject'] ?? 'No Subject',
                                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${fb['member_name'] ?? 'Unknown'} • $cat • $date',
                                                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11.5),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _statusColor(status).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _statusLabel(status),
                                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(status)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          fb['message'] ?? '',
                                          style: GoogleFonts.outfit(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (fb['admin_response'] != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Responded by ${fb['responded_by'] ?? 'Admin'}',
                                                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.reply_rounded, size: 14, color: AppColors.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tap to respond',
                                                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ],
                                        // Contact info
                                        const SizedBox(height: 6),
                                        Text(
                                          '${fb['member_email'] ?? ''} • ${fb['member_phone'] ?? ''}',
                                          style: GoogleFonts.outfit(fontSize: 10.5, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(String label, int count, String value) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

