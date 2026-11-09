import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_colors.dart';
import '../services/supabase_service.dart';

class ManageMembersScreen extends StatefulWidget {
  static const route = '/manage-members';
  const ManageMembersScreen({super.key});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await SupabaseService.adminFetchAllMembers();
      if (mounted) {
        setState(() {
          _members = members;
          _applyFilters();
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

  Future<void> _exportMembers() async {
    try {
      final List<String> csvRows = ['Name,Email,Phone,Role,Status,Branch'];
      for (var m in _filtered) {
        final name = m['full_name']?.toString() ?? 'Unknown';
        final email = m['email']?.toString() ?? '';
        final phone = m['phone']?.toString() ?? '';
        final role = m['role']?.toString() ?? '';
        final status = m['status']?.toString() ?? '';
        final branch = (m['form_details'] as Map?)?['branch']?.toString() ?? '';
        
        final safeName = name.replaceAll('"', '""');
        csvRows.add('"$safeName","$email","$phone","$role","$status","$branch"');
      }
      
      final csvString = csvRows.join('\n');
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/members_export.csv');
      await file.writeAsString(csvString);
      
      await Share.shareXFiles([XFile(file.path)], text: 'OneFellowship Members Export');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  void _applyFilters() {
    _filtered = _members.where((m) {
      final name = m['full_name']?.toString().toLowerCase() ?? '';
      final email = m['email']?.toString().toLowerCase() ?? '';
      final role = m['role']?.toString().toLowerCase() ?? 'member';
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
      final matchesRole = _filterRole == 'all' || role == _filterRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  void _showEditDialog(Map<String, dynamic> member) {
    String role = member['role']?.toString().toLowerCase() ?? 'member';
    String status = member['status']?.toString().toLowerCase() ?? 'active';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Edit Member', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (member['full_name']?.toString() ?? 'M')[0].toUpperCase(),
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(member['full_name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(member['email'] ?? '', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: ['member', 'admin', 'treasury', 'chairperson'].contains(role) ? role : 'member',
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'member', child: Text('Member')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'treasury', child: Text('Treasury')),
                      DropdownMenuItem(value: 'chairperson', child: Text('Chairperson')),
                    ],
                    onChanged: (val) => setDialogState(() => role = val!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: ['active', 'inactive', 'probation', 'suspended'].contains(status) ? status : 'active',
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      DropdownMenuItem(value: 'probation', child: Text('Probation')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    ],
                    onChanged: (val) => setDialogState(() => status = val!),
                  ),
                  const SizedBox(height: 16),
                  // View KYC & Residential Info Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showMemberKycSheet(member);
                      },
                      icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                      label: Text('View KYC & Residence Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Reset Password Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showResetPasswordDialog(member);
                      },
                      icon: const Icon(Icons.lock_reset_rounded, size: 18),
                      label: Text('Reset Password', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await SupabaseService.adminUpdateMember(member['id'].toString(), {'role': role, 'status': status});
                      await _loadData();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMemberKycSheet(Map<String, dynamic> member) {
    final fd = (member['form_details'] as Map<String, dynamic>?) ?? {};
    final idNumber = fd['national_id_number'] ?? fd['id_number'] ?? 'Not provided';
    final branch = fd['branch'] ?? 'Not set';
    final occupation = fd['occupation'] ?? fd['profession'] ?? 'Not set';
    final county = fd['county'] ?? 'Not set';
    final subCounty = fd['sub_county'] ?? fd['subcounty'] ?? 'Not set';
    final ward = fd['ward'] ?? fd['word'] ?? 'Not set';
    final village = fd['village'] ?? fd['estate'] ?? fd['residence'] ?? 'Not set';
    final nokName = fd['next_of_kin_full_name'] ?? fd['nok_name'] ?? 'Not provided';
    final nokPhone = fd['next_of_kin_phone_number'] ?? fd['nok_phone'] ?? 'Not provided';
    final nokId = fd['next_of_kin_national_id_number'] ?? fd['nok_id'] ?? 'Not provided';
    final nokIdType = fd['next_of_kin_id_type'] ?? fd['nok_id_type'] ?? 'ID Document';
    final nokRel = fd['relationship_to_you'] ?? 'Not set';
    final agreedRules = (fd['agreed_to_welfare_rules'] == true) || (member['agreed_to_welfare_rules'] == true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (member['full_name']?.toString() ?? 'M')[0].toUpperCase(),
                        style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member['full_name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(member['email'] ?? '', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),
                Text('Location & Administrative Origin', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
                const SizedBox(height: 8),
                _buildKycRow('County', county.toString()),
                _buildKycRow('Sub-County', subCounty.toString()),
                _buildKycRow('Ward', ward.toString()),
                _buildKycRow('Village / Estate', village.toString()),
                _buildKycRow('Branch', branch.toString()),
                _buildKycRow('Occupation', occupation.toString()),
                _buildKycRow('National ID', idNumber.toString()),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                Text('Next of Kin (Verified Beneficiary)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
                const SizedBox(height: 8),
                _buildKycRow('Full Name', nokName.toString()),
                _buildKycRow('Relationship', nokRel.toString()),
                _buildKycRow('Phone Number', nokPhone.toString()),
                _buildKycRow('$nokIdType No.', nokId.toString()),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                Text('Welfare Compliance & Ratification', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
                const SizedBox(height: 8),
                _buildKycRow('Rules Ratified', agreedRules ? '✅ Yes (Agreed & Bound)' : '❌ Not Ratified Yet'),
                _buildKycRow('Commitment Fee', 'KES 1,000 (Required)'),
                _buildKycRow('Min Contribution', 'KES 1,000 per case'),
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
                    child: Text('Close Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKycRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> member) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool isResetting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: Colors.orange.shade700, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Reset Password', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            (member['full_name']?.toString() ?? 'M')[0].toUpperCase(),
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member['full_name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(member['email'] ?? '', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // New password
                  Text('New Password', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: GoogleFonts.outfit(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Enter new password',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: GestureDetector(
                        onTap: () => setDialogState(() => obscurePassword = !obscurePassword),
                        child: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textMuted),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Confirm password
                  Text('Confirm Password', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    style: GoogleFonts.outfit(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Confirm new password',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: GestureDetector(
                        onTap: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        child: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textMuted),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Minimum 6 characters. The member will use this password to log in.',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isResetting ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit()),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: isResetting ? null : () async {
                    final newPassword = passwordController.text.trim();
                    final confirmPassword = confirmController.text.trim();

                    if (newPassword.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a password'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (newPassword.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (newPassword != confirmPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    setDialogState(() => isResetting = true);
                    try {
                      await SupabaseService.adminResetUserPassword(
                        userId: member['id'].toString(),
                        newPassword: newPassword,
                      );
                      if (context.mounted) Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Password reset successfully for ${member['full_name']}', style: GoogleFonts.outfit()),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isResetting = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: isResetting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Reset Password', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
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
        title: Text('Manage Members', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppColors.primary),
            onPressed: _exportMembers,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              bottom: true,
              child: RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _applyFilters();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search members...',
                        hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),

                  // Role filter chips
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFilterChip('All', 'all'),
                        _buildFilterChip('Members', 'member'),
                        _buildFilterChip('Admins', 'admin'),
                        _buildFilterChip('Treasury', 'treasury'),
                        _buildFilterChip('Chair', 'chairperson'),
                      ],
                    ),
                  ),

                  // Count
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_filtered.length} member${_filtered.length == 1 ? '' : 's'}',
                        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ),

                  // Members list
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(child: Text('No members found', style: GoogleFonts.outfit(color: AppColors.textMuted)))
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 28 + MediaQuery.of(context).padding.bottom),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final member = _filtered[index];
                              final name = member['full_name']?.toString() ?? 'Unknown';
                              final email = member['email']?.toString() ?? '';
                              final role = member['role']?.toString().toUpperCase() ?? 'MEMBER';
                              final status = member['status']?.toString().toUpperCase() ?? 'ACTIVE';
                              final isActive = status == 'ACTIVE';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                                color: Colors.white,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                      style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(email, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(status, style: TextStyle(color: isActive ? AppColors.success : AppColors.error, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(role, style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 20),
                                  onTap: () => _showEditDialog(member),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterRole == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        )),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _filterRole = value;
            _applyFilters();
          });
        },
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade200),
        showCheckmark: false,
      ),
    );
  }
}
