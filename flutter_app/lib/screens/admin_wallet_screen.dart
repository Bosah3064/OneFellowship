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

  void _showAddExpenseDialog() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dateCtrl = TextEditingController(text: dateStr);
    
    String type = 'expense'; // 'expense', 'payout', 'other'
    String authorityRole = 'Treasurer';
    String authorityName = SupabaseService.currentUser?.displayName ?? 'Admin Official';

    try {
      final m = await SupabaseService.fetchCurrentMember();
      if (m != null) {
        authorityName = m['full_name']?.toString() ?? authorityName;
        final r = (m['role'] ?? '').toString().toLowerCase();
        if (r == 'chairperson') authorityRole = 'Chairperson';
        else if (r == 'treasury' || r == 'treasurer') authorityRole = 'Treasurer';
        else if (r == 'secretary') authorityRole = 'Secretary';
      }
    } catch (_) {}

    final authorityNameCtrl = TextEditingController(text: authorityName);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Text('Record Expense / Trail', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Governance & Security Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.blue.shade800, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Leadership Audit Trail: This entry will be permanently logged with your authority title, date, and identity.',
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
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
                    hintText: 'e.g. 5000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description / Purpose / Notes',
                    hintText: 'e.g. Bereavement support disburse / hall hire',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: authorityRole,
                        decoration: InputDecoration(
                          labelText: 'Authority Role',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Treasurer', child: Text('Treasurer')),
                          DropdownMenuItem(value: 'Chairperson', child: Text('Chairperson')),
                          DropdownMenuItem(value: 'Secretary', child: Text('Secretary')),
                          DropdownMenuItem(value: 'Admin Official', child: Text('Admin Official')),
                        ],
                        onChanged: (v) {
                          if (v != null) setD(() => authorityRole = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: dateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Date (YYYY-MM-DD)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authorityNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Official Name (Logged Leader)',
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text);
                if (amt == null || amt <= 0 || descCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter valid amount and description')));
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final userId = SupabaseService.currentUser?.id;
                  final recordedBy = authorityNameCtrl.text.trim().isNotEmpty
                      ? authorityNameCtrl.text.trim()
                      : authorityName;
                  
                  await SupabaseService.adminAddExpense({
                    'amount': amt,
                    'description': descCtrl.text.trim(),
                    'type': type,
                    'status': 'pending', // Requires approval under Clause 5 & 7
                    'added_by': userId,
                    'recorded_by_name': recordedBy,
                    'recorded_by_role': authorityRole,
                    'expense_date': dateCtrl.text.trim().isNotEmpty ? dateCtrl.text.trim() : dateStr,
                  });
                  await _loadWalletData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Transaction recorded by $recordedBy ($authorityRole) and logged to Audit Trail!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Record & Trail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateExpenseStatus(String id, String newStatus, {Map<String, dynamic>? auditTrail}) async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.adminUpdateExpenseStatus(id, newStatus, auditTrail: auditTrail);
      await _loadWalletData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  void _showApprovalWithFraudWarningDialog(Map<String, dynamic> expense) {
    String selectedRole = 'Treasurer';
    bool confirmLegit = false;
    bool confirmFraudWarning = false;
    final amt = num.tryParse(expense['amount']?.toString() ?? '0') ?? 0;
    final desc = expense['description'] ?? 'No description';
    
    // Parse existing approvals
    final List<dynamic> rawApprovals = expense['approvals'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> approvals = rawApprovals
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    
    final currentUserId = SupabaseService.currentUser?.id;
    final bool alreadySigned = approvals.any((a) => a['approver_id'] == currentUserId);

    // Auto-detect role
    try {
      final curRole = (SupabaseService.currentUser?.userMetadata?['role'] ?? '').toString().toLowerCase();
      if (curRole.contains('chair')) {
        selectedRole = 'Chairperson';
      } else if (curRole.contains('sec')) {
        selectedRole = 'Secretary';
      } else {
        selectedRole = 'Treasurer';
      }
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final canApprove = confirmLegit && confirmFraudWarning && !alreadySigned;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(20),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded, color: AppColors.error, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Triple Leadership Authorization',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Welfare Constitution Clause 5 (3 Signatures Required)',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                          letterSpacing: 0.3,
                        ),
                      ),
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
                  const SizedBox(height: 10),

                  // Transaction Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Disbursement Request',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'KES ${amt.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          desc,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Multi-approval progress tracker
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LEADERSHIP SIGNATURES',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E40AF),
                                letterSpacing: 0.8,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E40AF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${approvals.length} / 3 APPROVED',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (approvals.isEmpty)
                          Text(
                            'No leaders have signed yet. 3 distinct signatures required before disbursement.',
                            style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.blue.shade900),
                          )
                        else
                          ...approvals.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final a = entry.value;
                            final name = a['approver_name'] ?? 'Official';
                            final r = a['approver_role'] ?? 'Leader';
                            final dt = (a['approved_at'] ?? '').toString().split('T').first;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$idx. $name ($r) • $dt',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        if (approvals.length < 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.pending_rounded, color: Colors.amber.shade700, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Awaiting ${3 - approvals.length} more leader signature(s)',
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (alreadySigned) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_rounded, color: Colors.amber.shade800, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have already signed this request. A different leader must provide the remaining signature.',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.amber.shade900, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Mandatory Fraud Warning Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'CONSTITUTIONAL POLICY MANDATE',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFB91C1C),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Triple Authorization (Clause 5): All withdrawals, disbursements, and payments must be authorized by three leaders (e.g., Chairperson, Secretary, and Treasurer). No single official may authorize withdrawals independently.\n'
                          '• Misappropriation & Fraud (Clause 7): Any embezzlement or unauthorized payout results in immediate restriction from fund access, suspension from duties pending independent audit, and criminal prosecution.',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF7F1D1D),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Approving Official Role
                  Text(
                    'Your Signing Role',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Treasurer', child: Text('Treasurer')),
                      DropdownMenuItem(value: 'Chairperson', child: Text('Chairperson')),
                      DropdownMenuItem(value: 'Secretary', child: Text('Secretary')),
                      DropdownMenuItem(value: 'Welfare Committee Member', child: Text('Welfare Committee Member')),
                    ],
                    onChanged: (v) {
                      if (v != null) setD(() => selectedRole = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Checkbox 1: Legitimacy
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: confirmLegit,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: alreadySigned ? null : (val) => setD(() => confirmLegit = val ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: alreadySigned ? null : () => setD(() => confirmLegit = !confirmLegit),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'I verify this expense is legitimate, supported by documentation, and complies with Welfare Fund principles.',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: AppColors.textPrimary, height: 1.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Checkbox 2: Fraud warning acknowledge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: confirmFraudWarning,
                        activeColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: alreadySigned ? null : (val) => setD(() => confirmFraudWarning = val ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: alreadySigned ? null : () => setD(() => confirmFraudWarning = !confirmFraudWarning),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'I understand fraudulent approvals carry immediate suspension, independent church audit, and legal prosecution.',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF991B1B),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                  backgroundColor: canApprove ? AppColors.success : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: canApprove
                    ? () async {
                        Navigator.pop(ctx);
                        try {
                          final updated = await SupabaseService.addExpenseApproval(
                            expenseId: expense['id'],
                            approverRole: selectedRole,
                          );
                          await _loadWalletData();
                          if (mounted) {
                            final count = updated.length;
                            final msg = count >= 3
                                ? '✅ Fully Authorized (3/3 Leaders)! Expense marked as Approved.'
                                : '✅ Signed as $selectedRole ($count/3 Leaders). Awaiting ${3 - count} more signature(s).';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: count >= 3 ? AppColors.success : AppColors.primary,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                label: Text(
                  alreadySigned ? 'Already Signed' : 'Sign & Authorize (${approvals.length}/3)',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
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
        title: Text('Organization Wallet', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              bottom: true,
              child: Column(
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Registration Fees',
                              amount: _totalRegistration,
                              color: Colors.teal,
                              icon: Icons.how_to_reg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Monthly Savings',
                              amount: _totalSavings,
                              color: Colors.blue,
                              icon: Icons.savings,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Member Payouts',
                              amount: _totalPaidOut,
                              color: AppColors.primary,
                              icon: Icons.card_giftcard_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(
                        title: 'Approved Expenses Disbursed',
                        amount: _totalApprovedExpenses,
                        color: AppColors.error,
                        icon: Icons.receipt_long_rounded,
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
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.of(context).padding.bottom),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            final status = (expense['status'] ?? '').toString().toLowerCase();
                            final amt = num.tryParse(expense['amount']?.toString() ?? '0') ?? 0;
                            final dateStr = expense['expense_date']?.toString();
                            final formattedDate = dateStr != null && dateStr.length >= 10
                              ? dateStr.substring(0, 10)
                              : 'Unknown date';

                            final rawApprovals = expense['approvals'] as List<dynamic>? ?? [];
                            final approvalsList = rawApprovals.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
                            final currentUserId = SupabaseService.currentUser?.id;
                            final bool alreadySigned = approvalsList.any((a) => a['approver_id'] == currentUserId);

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
                                              const SizedBox(height: 2),
                                              Text(
                                                'Recorded by: ${expense['recorded_by_name'] ?? expense['members']?['full_name'] ?? 'Authority'} (${expense['recorded_by_role'] ?? 'Leadership'}) • $formattedDate', 
                                                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                                              ),
                                              if (approvalsList.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Signed by: ${approvalsList.map((a) => "${a['approver_name']} (${a['approver_role']})").join(', ')}',
                                                  style: GoogleFonts.outfit(
                                                    color: status == 'approved' ? AppColors.success : const Color(0xFF1E40AF),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ] else if (expense['approved_by_name'] != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Authorized by: ${expense['approved_by_name']} (${expense['authorized_role'] ?? 'Executive'})',
                                                  style: GoogleFonts.outfit(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
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
                                              child: Text(
                                                status == 'pending'
                                                    ? '${approvalsList.length}/3 SIGNED'
                                                    : status.toUpperCase(),
                                                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    
                                    // Approval Actions (Only show if pending)
                                    if (status == 'pending') ...[
                                      const Divider(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.error,
                                                side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              onPressed: () => _updateExpenseStatus(expense['id'], 'rejected'),
                                              icon: const Icon(Icons.close_rounded, size: 16),
                                              label: Text('Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton.filledTonal(
                                            tooltip: 'Remind Leaders to Approve',
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.amber.shade100,
                                              padding: const EdgeInsets.all(12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () async {
                                              final count = await SupabaseService.notifyExpenseApprovers(
                                                expenseId: expense['id'],
                                                description: expense['description']?.toString() ?? 'Expense',
                                                amount: amt.toDouble(),
                                                currentApprovalCount: approvalsList.length,
                                                reason: 'reminder',
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('🔔 Sent approval reminder notification to $count leader(s)!'),
                                                    backgroundColor: AppColors.primary,
                                                  ),
                                                );
                                              }
                                            },
                                            icon: Icon(Icons.notifications_active_rounded, color: Colors.amber.shade900, size: 20),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: alreadySigned ? Colors.blue.shade700 : AppColors.success,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                elevation: 0,
                                              ),
                                              onPressed: () => _showApprovalWithFraudWarningDialog(expense),
                                              icon: Icon(
                                                alreadySigned ? Icons.check_circle_outline_rounded : Icons.verified_user_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              label: Text(
                                                alreadySigned ? 'Signed (${approvalsList.length}/3)' : 'Sign (${approvalsList.length}/3)',
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                                              ),
                                            ),
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
