import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';

class MemberPaymentHistoryDialog extends StatefulWidget {
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>> allPayments;
  final Function() onPaymentsUpdated;

  const MemberPaymentHistoryDialog({
    super.key,
    required this.member,
    required this.allPayments,
    required this.onPaymentsUpdated,
  });

  @override
  State<MemberPaymentHistoryDialog> createState() => _MemberPaymentHistoryDialogState();
}

class _MemberPaymentHistoryDialogState extends State<MemberPaymentHistoryDialog> {
  late int _selectedYear;
  bool _isLoading = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  List<Map<String, dynamic>> _getPaymentsForYear() {
    return widget.allPayments.where((p) {
      if (p['member_id'] != widget.member['id']) return false;
      final monthStr = (p['month']?.toString() ?? '').toLowerCase();
      return monthStr.contains(_selectedYear.toString());
    }).toList();
  }

  Map<String, dynamic>? _getPaymentForMonth(String monthCode, List<Map<String, dynamic>> yearlyPayments) {
    try {
      return yearlyPayments.firstWhere((p) {
        final m = (p['month']?.toString() ?? '').toLowerCase();
        return m.startsWith(monthCode.toLowerCase());
      });
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateOrAddPayment(String monthCode, Map<String, dynamic>? existingPayment) async {
    final fullMonthString = '$monthCode $_selectedYear';
    
    final amountController = TextEditingController(text: existingPayment?['amount']?.toString() ?? '500');
    String status = existingPayment?['status']?.toString().toLowerCase() ?? 'paid';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Update $fullMonthString', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (KES)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: ['pending', 'paid', 'late'].contains(status) ? status : 'paid',
                    decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'late', child: Text('Late')),
                    ],
                    onChanged: (val) => setDialogState(() => status = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      }
    );

    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    try {
      final amount = double.tryParse(amountController.text) ?? 0.0;
      if (existingPayment != null) {
        await SupabaseService.adminUpdatePayment(existingPayment['id'], {
          'status': status,
          'amount': amount,
          'payment_date': DateTime.now().toIso8601String(),
        });
      } else {
        await SupabaseService.adminAddPayment({
          'member_id': widget.member['id'],
          'member_name': widget.member['full_name'] ?? 'Unknown',
          'amount': amount,
          'month': fullMonthString,
          'payment_type': 'Monthly Contribution',
          'status': status,
          'payment_date': DateTime.now().toIso8601String(),
        });
      }
      
      await widget.onPaymentsUpdated();
      
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yearlyPayments = _getPaymentsForYear();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${widget.member['full_name']}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _selectedYear--),
              ),
              Text('$_selectedYear', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _selectedYear++),
              ),
            ],
          )
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final monthCode = _months[index];
                final payment = _getPaymentForMonth(monthCode, yearlyPayments);
                
                Color bgColor = Colors.grey.shade100;
                Color textColor = Colors.grey.shade600;
                String statusText = 'Missing';
                
                if (payment != null) {
                  final status = payment['status']?.toString().toLowerCase() ?? '';
                  if (status == 'paid') {
                    bgColor = AppColors.success.withOpacity(0.15);
                    textColor = AppColors.success;
                    statusText = 'Paid';
                  } else if (status == 'pending') {
                    bgColor = AppColors.warning.withOpacity(0.15);
                    textColor = Colors.orange.shade800;
                    statusText = 'Pending';
                  } else if (status == 'late') {
                    bgColor = AppColors.red.withOpacity(0.15);
                    textColor = AppColors.red;
                    statusText = 'Late';
                  }
                }

                return InkWell(
                  onTap: () => _updateOrAddPayment(monthCode, payment),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: textColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(monthCode, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 4),
                        Text(statusText, style: GoogleFonts.outfit(fontSize: 10, color: textColor)),
                        if (payment != null && statusText == 'Paid')
                          Text('KES ${payment['amount'] ?? 0}', style: GoogleFonts.outfit(fontSize: 9, color: textColor)),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
