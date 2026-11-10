import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';

class FeedbackScreen extends StatefulWidget {
  static const route = '/feedback';
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _myFeedback = [];

  @override
  void initState() {
    super.initState();
    _loadMyFeedback();
  }

  Future<void> _loadMyFeedback() async {
    setState(() => _isLoading = true);
    try {
      final feedback = await SupabaseService.fetchMyFeedback();
      if (mounted) setState(() { _myFeedback = feedback; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSubmitDialog() {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String category = 'Concern';

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
                  child: const Icon(Icons.feedback_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Submit Feedback',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Concern', child: Text('🔴 Concern')),
                      DropdownMenuItem(value: 'Complaint', child: Text('⚠️ Complaint')),
                      DropdownMenuItem(value: 'Suggestion', child: Text('💡 Suggestion')),
                      DropdownMenuItem(value: 'Appreciation', child: Text('🌟 Appreciation')),
                      DropdownMenuItem(value: 'Question', child: Text('❓ Question')),
                    ],
                    onChanged: (v) { if (v != null) setD(() => category = v); },
                  ),
                  const SizedBox(height: 14),
                  Text('Subject', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: subjectCtrl,
                    decoration: InputDecoration(
                      hintText: 'Brief subject line...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Message', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Describe your feedback in detail...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your feedback is confidential and will only be reviewed by authorized administrators.',
                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.green.shade800, height: 1.3),
                          ),
                        ),
                      ],
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
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  if (subjectCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in subject and message')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  setState(() => _isSubmitting = true);
                  try {
                    await SupabaseService.submitFeedback(
                      category: category,
                      subject: subjectCtrl.text.trim(),
                      message: messageCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Feedback submitted successfully! Our team will review it.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      _loadMyFeedback();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                  if (mounted) setState(() => _isSubmitting = false);
                },
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                label: Text('Submit', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Feedback & Concerns', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading || _isSubmitting
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Voice Matters',
                                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Share concerns, suggestions, or compliments confidentially with the leadership team.',
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.white70, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showSubmitDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: Text('New Feedback', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),

                // My Submissions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        'My Submissions (${_myFeedback.length})',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _myFeedback.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('No feedback submitted yet',
                                  style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Tap "New Feedback" to share your thoughts.',
                                  style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _loadMyFeedback,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.of(context).padding.bottom),
                            itemCount: _myFeedback.length,
                            itemBuilder: (context, index) {
                              final fb = _myFeedback[index];
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
                                  onTap: () => _showFeedbackDetail(fb),
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
                                                    '$cat • $date',
                                                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
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
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: _statusColor(status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (fb['admin_response'] != null) ...[
                                          const Divider(height: 20),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.reply_rounded, size: 16, color: AppColors.success),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Response from ${fb['responded_by'] ?? 'Admin'}',
                                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      fb['admin_response'],
                                                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                                                      maxLines: 3,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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

  void _showFeedbackDetail(Map<String, dynamic> fb) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final status = (fb['status'] ?? 'open').toString();
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(_categoryIcon(fb['category'] ?? ''), style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fb['subject'] ?? 'No Subject',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17)),
                          Text('${fb['category']} • ${(fb['created_at'] ?? '').toString().split('T').first}',
                              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(status),
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),
                Text('Your Message', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(fb['message'] ?? '', style: GoogleFonts.outfit(fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
                ),
                if (fb['admin_response'] != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('Admin Response', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.success)),
                  const SizedBox(height: 4),
                  Text('By ${fb['responded_by'] ?? 'Administrator'} • ${(fb['responded_at'] ?? '').toString().split('T').first}',
                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(fb['admin_response'], style: GoogleFonts.outfit(fontSize: 13, height: 1.5, color: AppColors.textPrimary)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

