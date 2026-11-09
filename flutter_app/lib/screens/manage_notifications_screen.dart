import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';

class ManageNotificationsScreen extends StatefulWidget {
  static const route = '/manage-notifications';
  const ManageNotificationsScreen({super.key});

  @override
  State<ManageNotificationsScreen> createState() => _ManageNotificationsScreenState();
}

class _ManageNotificationsScreenState extends State<ManageNotificationsScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _selectedMemberIds = {};

  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _type = 'info';

  final List<Map<String, String>> _templates = [
    {
      'label': '💰 Monthly Welfare (KES 1,000)',
      'title': 'Monthly Welfare Contribution (KES 1,000)',
      'message': 'Dear brethren, this is a friendly reminder to remit your monthly benevolent contribution of KES 1,000. Under our Constitution, a 7-day grace period applies. Thank you for standing together!',
      'type': 'payment',
    },
    {
      'label': '🕊️ Bereavement Notice',
      'title': 'Urgent Welfare Notice: Bereavement Support',
      'message': 'Dear brethren, we regret to inform you of the passing of a declared family member of our brother/sister. In accordance with Clause 5 of our Constitution, welfare support is underway. Let us stand united in prayer and assistance.',
      'type': 'system',
    },
    {
      'label': '💒 Wedding Announcement',
      'title': 'Fellowship Celebration: Wedding Support',
      'message': 'We rejoice with our brother/sister on their upcoming wedding! Official notice has been approved under Welfare Clause 5. Let us unite to support and bless their union.',
      'type': 'approval',
    },
    {
      'label': '⏱️ 7-Day Grace Notice',
      'title': 'Notice: 7-Day Statutory Grace Period',
      'message': 'Notice under Welfare Constitution Clause 7: Please settle your pending welfare contribution within the 7-day grace period to keep your membership in active standing.',
      'type': 'system',
    },
    {
      'label': '📜 Ratified Constitution',
      'title': 'Ratified Benevolent Constitution & Policies',
      'message': 'The official OneFellowship Benevolent Welfare Fund Constitution has been ratified. All members are kindly requested to review and affirm the policies under the Welfare Constitution section.',
      'type': 'info',
    },
    {
      'label': '🛡️ Financial Stewardship Memo',
      'title': 'Leadership Memo: Triple Authorization Mandate',
      'message': 'Official reminder: Under Welfare Constitution Clause 5 & 6, all disbursements require joint authorization from the Chairperson, Secretary, and Treasurer. No single official may independently authorize funds.',
      'type': 'info',
    },
  ];

  void _applyTemplate(Map<String, String> t) {
    setState(() {
      _titleCtrl.text = t['title'] ?? '';
      _messageCtrl.text = t['message'] ?? '';
      _type = t['type'] ?? 'info';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template "${t['label']}" applied!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await SupabaseService.adminFetchAllMembers();
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((m) {
      final n = (m['full_name']?.toString() ?? '').toLowerCase();
      return n.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _sendNotification() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one member')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final member = await SupabaseService.fetchCurrentMember();
      final senderName = member?['full_name'] ?? SupabaseService.currentUser?.displayName ?? 'Admin';
      final senderRole = (member?['role'] ?? 'admin').toString().toUpperCase();

      await SupabaseService.adminSendNotification(
        memberIds: _selectedMemberIds.toList(),
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        type: _type,
        senderName: senderName,
        senderId: SupabaseService.currentUser?.id,
        senderRole: senderRole,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Notification sent to ${_selectedMemberIds.length} members'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context); // Go back after sending
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Send Notification', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/admin-audit-logs'),
            icon: const Icon(Icons.security_rounded, size: 16, color: AppColors.primary),
            label: Text(
              'Audit Trail',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              bottom: true,
              child: Column(
              children: [
                // Form Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Templates Section Header
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Quick Templates (Tap to Auto-Fill)',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Horizontal Template Chips
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _templates.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final t = _templates[i];
                            return ActionChip(
                              backgroundColor: const Color(0xFFF1F5F9),
                              label: Text(
                                t['label'] ?? '',
                                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                              onPressed: () => _applyTemplate(t),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Notification Title',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Message Body',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: InputDecoration(
                          labelText: 'Notification Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'info', child: Text('Information (Blue)')),
                          DropdownMenuItem(value: 'system', child: Text('System Alert (Yellow)')),
                          DropdownMenuItem(value: 'payment', child: Text('Payment Request (Amber)')),
                          DropdownMenuItem(value: 'approval', child: Text('Approval (Green)')),
                        ],
                        onChanged: (v) => setState(() => _type = v!),
                      ),
                    ],
                  ),
                ),
                
                // Select Members Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search members...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.checklist),
                        label: const Text('All'),
                        onPressed: () {
                          final ids = _filteredMembers.map((e) => e['id'].toString()).toSet();
                          setState(() {
                            if (_selectedMemberIds.containsAll(ids)) {
                              _selectedMemberIds.removeAll(ids);
                            } else {
                              _selectedMemberIds.addAll(ids);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Members List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (ctx, i) {
                      final m = _filteredMembers[i];
                      final id = m['id'].toString();
                      final isSelected = _selectedMemberIds.contains(id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedMemberIds.add(id);
                              } else {
                                _selectedMemberIds.remove(id);
                              }
                            });
                          },
                          title: Text(m['full_name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                          subtitle: Text(m['phone'] ?? '', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                          activeColor: AppColors.primary,
                        ),
                      );
                    },
                  ),
                ),

                // Footer Actions
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedMemberIds.isEmpty ? Colors.grey : AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _selectedMemberIds.isEmpty ? null : _sendNotification,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text(
                        'Send to ${_selectedMemberIds.length} Members',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
