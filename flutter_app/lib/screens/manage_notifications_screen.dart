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
      await SupabaseService.adminSendNotification(
        memberIds: _selectedMemberIds.toList(),
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        type: _type,
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Form Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
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
                          DropdownMenuItem(value: 'payment', child: Text('Payment Request (Purple)')),
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
                  padding: const EdgeInsets.all(16),
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
    );
  }
}
