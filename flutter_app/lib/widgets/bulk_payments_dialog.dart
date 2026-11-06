import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';

class BulkPaymentsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Function() onPaymentsAdded;

  const BulkPaymentsDialog({
    super.key,
    required this.members,
    required this.onPaymentsAdded,
  });

  @override
  State<BulkPaymentsDialog> createState() => _BulkPaymentsDialogState();
}

class _BulkPaymentsDialogState extends State<BulkPaymentsDialog> {
  bool _isLoading = false;
  final Set<String> _selectedMemberIds = {};
  
  final _amountController = TextEditingController(text: '500');
  String _month = '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][DateTime.now().month-1]} ${DateTime.now().year}';
  String _type = 'Monthly Contribution';
  String _status = 'paid';
  DateTime _paymentDate = DateTime.now();

  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return widget.members;
    return widget.members.where((m) {
      final name = (m['full_name']?.toString() ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _toggleAll() {
    final filteredIds = _filteredMembers.map((e) => e['id'].toString()).toSet();
    setState(() {
      if (_selectedMemberIds.containsAll(filteredIds)) {
        _selectedMemberIds.removeAll(filteredIds);
      } else {
        _selectedMemberIds.addAll(filteredIds);
      }
    });
  }

  Future<void> _submitBulk() async {
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one member')));
      return;
    }
    
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    
    setState(() => _isLoading = true);
    int added = 0;
    try {
      for (final memberId in _selectedMemberIds) {
        final memberName = widget.members.firstWhere((m) => m['id'].toString() == memberId, orElse: () => {})['full_name'] ?? 'Unknown';
        await SupabaseService.adminAddPayment({
          'member_id': memberId,
          'member_name': memberName,
          'amount': amount,
          'month': _month,
          'payment_type': _type,
          'status': _status,
          'payment_date': _paymentDate.toIso8601String(),
        });
        added++;
      }
      await widget.onPaymentsAdded();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Successfully added $added payments'),
          backgroundColor: AppColors.success,
        ));
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Bulk Add Payments', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Amount (KES)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'paid', child: Text('Paid')),
                          DropdownMenuItem(value: 'late', child: Text('Late')),
                        ],
                        onChanged: (val) => setState(() => _status = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _type,
                        decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'Monthly Contribution', child: Text('Monthly Contribution')),
                          DropdownMenuItem(value: 'Registration Fee', child: Text('Registration Fee')),
                          DropdownMenuItem(value: 'Penalty', child: Text('Penalty')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (val) => setState(() => _type = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                     Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _month,
                        decoration: InputDecoration(labelText: 'Month', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true),
                        items: [
                          'Jan 2026', 'Feb 2026', 'Mar 2026', 'Apr 2026', 'May 2026', 'Jun 2026',
                          'Jul 2026', 'Aug 2026', 'Sep 2026', 'Oct 2026', 'Nov 2026', 'Dec 2026',
                          'Jan 2027', 'Feb 2027', 'Mar 2027', 'Apr 2027', 'May 2027', 'Jun 2027',
                        ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (val) => setState(() => _month = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search members...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.checklist),
                      label: const Text('Toggle All'),
                      onPressed: _toggleAll,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final memberId = member['id'].toString();
                        final isSelected = _selectedMemberIds.contains(memberId);
                        
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedMemberIds.add(memberId);
                              } else {
                                _selectedMemberIds.remove(memberId);
                              }
                            });
                          },
                          title: Text(member['full_name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(member['phone'] ?? '', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                          activeColor: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
                if (_selectedMemberIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${_selectedMemberIds.length} members selected', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _submitBulk,
          icon: const Icon(Icons.save, color: Colors.white, size: 18),
          label: const Text('Apply to Selected', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
