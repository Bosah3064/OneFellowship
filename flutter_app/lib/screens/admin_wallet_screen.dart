import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';

class AdminWalletScreen extends StatefulWidget {
  static const route = '/admin-wallet';
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _expenses = [];

  // Derived financial metrics
  double _totalCollected = 0;
  double _totalSavings = 0;
  double _totalRegistration = 0;
  double _totalPaidOut = 0;
  double _totalApprovedExpenses = 0;
  double get _actualBalance => _totalCollected - _totalPaidOut - _totalApprovedExpenses;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);
    try {
      final payments = await SupabaseService.adminFetchAllPayments();
      final expenses = await SupabaseService.adminFetchAllExpenses();

      double collected = 0;
      double savings = 0;
      double registration = 0;
      double paidOut = 0;
      double approvedExps = 0;

      // 1. Calculate Collections and Payouts from payments table
      for (final p in payments) {
        if ((p['status'] ?? '').toString().toLowerCase() == 'paid') {
          final amt = num.tryParse(p['amount']?.toString() ?? '0')?.toDouble() ?? 0.0;
          collected += amt;
          
          final type = (p['payment_type'] ?? p['type'] ?? '').toString().toLowerCase();
          if (type.contains('reg')) {
            registration += amt;
          } else {
            savings += amt;
          }
          
          if ((p['payout_status'] ?? '').toString().toLowerCase() == 'paid_out') {
            paidOut += amt;
          }
        }
      }

      // 2. Calculate Admin Expenses
      for (final e in expenses) {
        if ((e['status'] ?? '').toString().toLowerCase() == 'approved') {
          final type = (e['type'] ?? '').toString().toLowerCase();
          if (type != 'payout') {
            approvedExps += num.tryParse(e['amount']?.toString() ?? '0')?.toDouble() ?? 0.0;
          }
        }
      }

      if (mounted) {
        setState(() {
          _payments = payments;
          _expenses = expenses;
          _totalCollected = collected;
          _totalSavings = savings;
          _totalRegistration = registration;
          _totalPaidOut = paidOut;
          _totalApprovedExpenses = approvedExps;
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

  void _showAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'expense'; // 'expense', 'payout', 'other'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Record Transaction', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: InputDecoration(
                    labelText: 'Transaction Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Admin Expense')),
                    DropdownMenuItem(value: 'payout', child: Text('Manual Payout Logging')),
                    DropdownMenuItem(value: 'other', child: Text('Other Deduction')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setD(() {
                        type = v;
                        if (type == 'payout') descCtrl.text = 'End of year payout';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (KES)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description / Notes',
                    hintText: 'e.g. Registration fees used for hosting',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text);
                if (amt == null || amt <= 0 || descCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid input')));
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final userId = SupabaseService.currentUser?.id;
                  await SupabaseService.adminAddExpense({
                    'amount': amt,
                    'description': descCtrl.text,
                    'type': type,
                    'status': 'pending', // Requires approval
                    'added_by': userId,
                  });
                  await _loadWalletData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Transaction submitted for approval')));
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateExpenseStatus(String id, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.adminUpdateExpenseStatus(id, newStatus);
      await _loadWalletData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
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
        title: Text('Organization Wallet', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Financial Summary Cards
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryCard(
                        title: 'Actual Cash Balance',
                        amount: _actualBalance,
                        color: AppColors.primary,
                        icon: Icons.account_balance_wallet_rounded,
                        isLarge: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Total Inflow',
                              amount: _totalCollected,
                              color: AppColors.success,
                              icon: Icons.account_balance_wallet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Registration Fees',
                              amount: _totalRegistration,
                              color: Colors.teal,
                              icon: Icons.how_to_reg,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Monthly Savings',
                              amount: _totalSavings,
                              color: Colors.blue,
                              icon: Icons.savings,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Member Payouts',
                              amount: _totalPaidOut,
                              color: AppColors.purple,
                              icon: Icons.card_giftcard_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Approved Expenses',
                              amount: _totalApprovedExpenses,
                              color: AppColors.error,
                              icon: Icons.receipt_long_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Transactions Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transaction Ledger', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: _showAddExpenseDialog,
                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                        label: const Text('Add Record', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),

                // Expenses List
                Expanded(
                  child: _expenses.isEmpty
                      ? Center(child: Text('No recorded transactions yet', style: GoogleFonts.outfit(color: AppColors.textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            final status = (expense['status'] ?? '').toString().toLowerCase();
                            final amt = num.tryParse(expense['amount']?.toString() ?? '0') ?? 0;
                            final dateStr = expense['expense_date']?.toString();
                            final formattedDate = dateStr != null && dateStr.length >= 10
                              ? dateStr.substring(0, 10)
                              : 'Unknown date';

                            Color statusColor = AppColors.warning;
                            IconData statusIcon = Icons.pending_actions;
                            if (status == 'approved') { statusColor = AppColors.success; statusIcon = Icons.check_circle; }
                            if (status == 'rejected') { statusColor = AppColors.error; statusIcon = Icons.cancel; }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: statusColor.withOpacity(0.1),
                                          child: Icon(statusIcon, color: statusColor, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(expense['description'] ?? 'No description', 
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                                              Text('By: ${expense['members']?['full_name'] ?? 'Unknown'} • $formattedDate', 
                                                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('- KES $amt', 
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.error)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                              child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    
                                    // Approval Actions (Only show if pending)
                                    if (status == 'pending') ...[
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _updateExpenseStatus(expense['id'], 'rejected'),
                                            icon: const Icon(Icons.close, color: AppColors.error, size: 16),
                                            label: const Text('Reject', style: TextStyle(color: AppColors.error)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.success,
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                            ),
                                            onPressed: () => _updateExpenseStatus(expense['id'], 'approved'),
                                            icon: const Icon(Icons.check, color: Colors.white, size: 16),
                                            label: const Text('Approve', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard({required String title, required double amount, required Color color, required IconData icon, bool isLarge = false}) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 20 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isLarge ? 24 : 16),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600, fontSize: isLarge ? 16 : 12))),
            ],
          ),
          SizedBox(height: isLarge ? 12 : 8),
          Text(
            'KES ${amount.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: isLarge ? 28 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
