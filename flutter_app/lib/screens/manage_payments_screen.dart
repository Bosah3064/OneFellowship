import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_colors.dart';
import '../services/supabase_service.dart';

// ═══════════════════════════════════════════════════════════════
// ManagePaymentsScreen – 3 Tabs:
//   1. Payments   (list / filter / search / edit / mark-as-paid)
//   2. Member History (search member → 12-month grid, editable)
//   3. Bulk Actions   (select multiple members → add payment)
// ═══════════════════════════════════════════════════════════════

class ManagePaymentsScreen extends StatefulWidget {
  static const route = '/manage-payments';
  const ManagePaymentsScreen({super.key});

  @override
  State<ManagePaymentsScreen> createState() => _ManagePaymentsScreenState();
}

class _ManagePaymentsScreenState extends State<ManagePaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  // ── Tab 1 state ──
  String _selectedFilter = 'All';
  String _searchQuery = '';
  String _summarySearchQuery = '';

  // ── Tab 2 state ──
  String _memberSearchQuery = '';
  Map<String, dynamic>? _selectedMember;
  int _selectedYear = DateTime.now().year;

  // ── Tab 3 state ──
  final Set<String> _bulkSelectedIds = {};
  String _bulkSearch = '';
  final _bulkAmountCtrl = TextEditingController(text: '500');
  late String _bulkMonth;
  String _bulkType = 'Monthly Contribution';
  String _bulkStatus = 'paid';

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _bulkMonth =
        '${_monthNames[DateTime.now().month - 1]} ${DateTime.now().year}';
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bulkAmountCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATA
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final payments = await SupabaseService.adminFetchAllPayments();
      final members = await SupabaseService.adminFetchAllMembers();
      if (mounted) {
        setState(() {
          _payments = payments;
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  FILTERED PAYMENTS (Tab 1)
  // ═══════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredPayments {
    var list = _payments;
    if (_selectedFilter != 'All') {
      final f = _selectedFilter.toLowerCase();
      list = list.where((p) {
        final status = p['status']?.toString().toLowerCase() ?? '';
        final type =
            (p['payment_type'] ?? p['type'])?.toString().toLowerCase() ?? '';
        final isStatus = status == f;
        final isType = type.contains(f.replaceAll(' fee', '').replaceAll(' contribution', ''));
        return isStatus || isType;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final name =
            (p['members'] as Map?)?['full_name']?.toString().toLowerCase() ??
                '';
        final month = p['month']?.toString().toLowerCase() ?? '';
        return name.contains(q) || month.contains(q);
      }).toList();
    }
    return list;
  }

  // ═══════════════════════════════════════════════════════════════
  //  GENERATE MONTHLY PENDING
  // ═══════════════════════════════════════════════════════════════
  Future<void> _generateMonthlyPending() async {
    final now = DateTime.now();
    // Let admin pick month via a real calendar
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pick a month to generate pending payments',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final currentMonth = '${_monthNames[picked.month - 1]} ${picked.year}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Generate Pending Payments',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_month, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(currentMonth,
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ]),
            ),
            const SizedBox(height: 16),
            Text(
              'Create "Pending" entries for all active members who don\'t already have a payment for $currentMonth.',
              style: GoogleFonts.outfit(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Generate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final activeMembers = _members
          .where(
              (m) => (m['status']?.toString().toLowerCase() ?? '') == 'active')
          .toList();

      final existingIds = _payments
          .where((p) =>
              (p['month']?.toString() ?? '').toLowerCase() ==
              currentMonth.toLowerCase())
          .map((p) => p['member_id']?.toString())
          .toSet();

      int created = 0;
      for (final member in activeMembers) {
        final id = member['id']?.toString();
        if (id != null && !existingIds.contains(id)) {
          await SupabaseService.adminAddPayment({
            'member_id': id,
            'member_name': member['full_name'] ?? 'Unknown',
            'amount': 0,
            'month': currentMonth,
            'payment_type': 'Monthly Contribution',
            'status': 'pending',
            'payment_date': DateTime.now().toIso8601String().substring(0, 10),
          });
          created++;
        }
      }

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('✅ Created $created pending payment(s) for $currentMonth'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  EXPORT CSV
  // ═══════════════════════════════════════════════════════════════
  Future<void> _exportPayments() async {
    try {
      final rows = <String>['Name,Month,Amount,Type,Status,Date'];
      for (var p in _filteredPayments) {
        final name = (p['members'] as Map?)?['full_name']?.toString() ??
            p['member_name']?.toString() ??
            'Unknown';
        final month = p['month']?.toString() ?? '';
        final amount = p['amount']?.toString() ?? '0';
        final type = (p['payment_type'] ?? p['type'])?.toString() ?? '';
        final status = p['status']?.toString() ?? '';
        final date = p['payment_date']?.toString() ?? '';
        rows.add(
            '"${name.replaceAll('"', '""')}","$month","$amount","$type","$status","$date"');
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/payments_export.csv');
      await file.writeAsString(rows.join('\n'));
      await Share.shareXFiles([XFile(file.path)],
          text: 'Glamorous Care Payments Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  MARK AS PAID  (quick action on a pending card)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _markAsPaid(Map<String, dynamic> payment) async {
    final amountCtrl =
        TextEditingController(text: payment['amount']?.toString() ?? '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Payment',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (payment['members'] as Map?)?['full_name']?.toString() ??
                  'Member',
              style:
                  GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(payment['month']?.toString() ?? '',
                style: GoogleFonts.outfit(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount Paid (KES)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixText: 'KES ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              final a = double.tryParse(amountCtrl.text) ?? 0;
              if (a <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
            label: const Text('Mark as Paid',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseService.adminUpdatePayment(payment['id'], {
        'status': 'paid',
        'amount': int.tryParse(amountCtrl.text) ?? 0,
        'payment_date': DateTime.now().toIso8601String().substring(0, 10),
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Payment confirmed for KES ${amountCtrl.text}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ADD / EDIT PAYMENT DIALOG (with real calendar date picker)
  // ═══════════════════════════════════════════════════════════════
  void _showPaymentDialog([Map<String, dynamic>? payment]) {
    final isEditing = payment != null;
    String? selectedMemberId =
        isEditing ? payment['member_id']?.toString() : null;
    final amountCtrl = TextEditingController(
        text: isEditing ? payment['amount']?.toString() : '');
    String month = isEditing ? payment['month']?.toString() ?? '' : '';
    String type = isEditing
        ? (payment['payment_type'] ?? payment['type'])?.toString() ??
            'Monthly Contribution'
        : 'Monthly Contribution';
    String status = isEditing
        ? payment['status']?.toString().toLowerCase() ?? 'pending'
        : 'pending';
    DateTime selectedDate = isEditing && payment['payment_date'] != null
        ? DateTime.tryParse(payment['payment_date'].toString()) ??
            DateTime.now()
        : DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(isEditing ? 'Edit Payment' : 'Add Payment',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Member selector (new only)
                    if (!isEditing)
                      DropdownButtonFormField<String>(
                        value: selectedMemberId,
                        decoration: InputDecoration(
                            labelText: 'Member',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))),
                        items: _members
                            .map((m) => DropdownMenuItem(
                                value: m['id'].toString(),
                                child: Text(
                                    m['full_name']?.toString() ?? 'Unknown')))
                            .toList(),
                        onChanged: (v) => setD(() => selectedMemberId = v),
                      ),
                    const SizedBox(height: 12),

                    // Amount
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Amount (KES)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 12),

                    // Month Picker
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(
                                colorScheme: const ColorScheme.light(
                                    primary: AppColors.primary)),
                            child: child!,
                          ),
                        );
                        if (d != null) {
                          setD(() => month = '${_monthNames[d.month - 1]} ${d.year}');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                month.isEmpty ? 'Select Month' : 'Month: $month',
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    color: month.isEmpty
                                        ? Colors.grey.shade600
                                        : Colors.black)),
                            const Icon(Icons.calendar_month,
                                color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type
                    DropdownButtonFormField<String>(
                      value: [
                        'Monthly Contribution',
                        'Registration Fee',
                        'Penalty',
                        'Other'
                      ].contains(type)
                          ? type
                          : 'Monthly Contribution',
                      decoration: InputDecoration(
                          labelText: 'Payment Type',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12))),
                      items: const [
                        DropdownMenuItem(
                            value: 'Monthly Contribution',
                            child: Text('Monthly Contribution')),
                        DropdownMenuItem(
                            value: 'Registration Fee',
                            child: Text('Registration Fee')),
                        DropdownMenuItem(
                            value: 'Penalty', child: Text('Penalty')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setD(() => type = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Status
                    DropdownButtonFormField<String>(
                      value: ['pending', 'paid', 'late'].contains(status)
                          ? status
                          : 'pending',
                      decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12))),
                      items: const [
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'late', child: Text('Late')),
                      ],
                      onChanged: (v) => setD(() => status = v!),
                    ),
                    const SizedBox(height: 12),

                    // Date picker
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(
                                colorScheme: const ColorScheme.light(
                                    primary: AppColors.primary)),
                            child: child!,
                          ),
                        );
                        if (d != null) setD(() => selectedDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'Date: ${selectedDate.toString().split(' ')[0]}',
                                style: GoogleFonts.outfit(fontSize: 16)),
                            const Icon(Icons.calendar_month,
                                color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (!isEditing && selectedMemberId == null) return;

                    // --- Duplicate check (same user + month + type) ---
                    if (!isEditing) {
                      final duplicate = _payments.any((p) =>
                          p['member_id']?.toString() == selectedMemberId &&
                          (p['month']?.toString().toLowerCase() ?? '') == month.toLowerCase() &&
                          (p['payment_type']?.toString().toLowerCase() ?? '') == type.toLowerCase());
                      if (duplicate) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('⚠️ A "$type" payment for "$month" already exists for this member. Edit the existing record instead.'),
                          backgroundColor: Colors.orange.shade700,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ));
                        return;
                      }
                    }

                    final data = {
                      if (!isEditing) 'member_id': selectedMemberId,
                      if (!isEditing)
                        'member_name': _members.firstWhere(
                                (m) => m['id'].toString() == selectedMemberId,
                                orElse: () => {})['full_name'] ??
                            'Unknown',
                      'amount': int.tryParse(amountCtrl.text) ?? 0,
                      'month': month,
                      'payment_type': type,
                      'status': status,
                      'payment_date': selectedDate.toIso8601String().substring(0, 10),
                    };
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      if (isEditing) {
                        await SupabaseService.adminUpdatePayment(
                            payment['id'], data);
                      } else {
                        await SupabaseService.adminAddPayment(data);
                      }
                      await _loadData();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: Text(isEditing ? 'Save' : 'Add Payment',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DELETE PAYMENT
  // ═══════════════════════════════════════════════════════════════
  Future<void> _deletePayment(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Payment'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.adminDeletePayment(id);
        await _loadData();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  // Helpers
  static List<String> get _allMonthOptions {
    final list = <String>[];
    for (int y = 2025; y <= 2028; y++) {
      for (final m in _monthNames) {
        list.add('$m $y');
      }
    }
    return list;
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Manage Payments',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppColors.primary),
            onPressed: _exportPayments,
            tooltip: 'Export CSV',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.primary),
            onPressed: _generateMonthlyPending,
            tooltip: 'Generate Monthly Pending',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.primary),
            onPressed: () => _showPaymentDialog(),
            tooltip: 'Add Payment',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded, size: 20), text: 'Payments'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 20), text: 'Summary'),
            Tab(
                icon: Icon(Icons.person_search_rounded, size: 20),
                text: 'Member History'),
            Tab(
                icon: Icon(Icons.library_add_rounded, size: 20),
                text: 'Bulk Actions'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentsTab(),
                _buildSummaryTab(),
                _buildMemberHistoryTab(),
                _buildBulkActionsTab(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 1 – PAYMENTS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPaymentsTab() {
    final payments = _filteredPayments;
    final pendingCount = payments
        .where((p) =>
            (p['status']?.toString().toLowerCase() ?? '') == 'pending')
        .length;
    final paidCount = payments
        .where(
            (p) => (p['status']?.toString().toLowerCase() ?? '') == 'paid')
        .length;

    // Auto-filter: members who haven't paid the current month
    final currentMonthStr =
        '${_monthNames[DateTime.now().month - 1]} ${DateTime.now().year}';
    final unpaidThisMonth = _members.where((m) {
      final memberId = m['id']?.toString();
      return !_payments.any((p) =>
          p['member_id']?.toString() == memberId &&
          (p['month']?.toString() ?? '').toLowerCase() ==
              currentMonthStr.toLowerCase() &&
          p['status']?.toString().toLowerCase() == 'paid');
    }).length;

    return Column(
      children: [
        // Summary bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              _buildStatBadge('Pending', pendingCount, AppColors.warning),
              const SizedBox(width: 8),
              _buildStatBadge('Paid', paidCount, AppColors.success),
              const SizedBox(width: 8),
              _buildStatBadge('Total', payments.length, AppColors.primary),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _selectedFilter = 'Pending');
                },
                child: _buildStatBadge(
                    'Unpaid Now', unpaidThisMonth, AppColors.error),
              ),
            ],
          ),
        ),

        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by name or month...',
              hintStyle:
                  GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'All',
                'Pending',
                'Paid',
                'Late',
                'Registration Fee',
                'Monthly Contribution'
              ].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        )),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedFilter = filter),
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade200),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: payments.isEmpty
                ? Center(
                    child: Text('No payments found',
                        style:
                            GoogleFonts.outfit(color: AppColors.textMuted)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: payments.length,
                    itemBuilder: (context, i) =>
                        _buildPaymentCard(payments[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final amount = num.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
    final month = payment['month']?.toString() ?? '';
    final status = payment['status']?.toString().toLowerCase() ?? 'pending';
    final type = (payment['payment_type'] ?? payment['type'])?.toString() ?? '';
    final memberName =
        (payment['members'] as Map?)?['full_name']?.toString() ?? 'Unknown';
    final isPending = status == 'pending';
    final isPaid = status == 'paid';

    Color statusColor = AppColors.warning;
    IconData statusIcon = Icons.pending_actions;
    if (isPaid) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
    }
    if (status == 'late') {
      statusColor = AppColors.error;
      statusIcon = Icons.warning_rounded;
    }

    final isReg = type.toLowerCase().contains('registration') ||
        type.toLowerCase().contains('reg');

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
            Row(children: [
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
                    Text(memberName,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(month,
                        style: GoogleFonts.outfit(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount > 0
                        ? 'KES ${amount.toStringAsFixed(0)}'
                        : 'KES --',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color:
                            isPaid ? AppColors.success : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isReg ? AppColors.purple : AppColors.primary)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isReg ? 'REGISTRATION' : type.toUpperCase(),
                  style: TextStyle(
                      color: isReg ? AppColors.purple : AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (isPending)
                SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: () => _markAsPaid(payment),
                    icon:
                        const Icon(Icons.check, color: Colors.white, size: 14),
                    label: Text('Paid',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              const SizedBox(width: 6),
              SizedBox(
                height: 30,
                width: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.edit, color: AppColors.textMuted),
                  onPressed: () => _showPaymentDialog(payment),
                ),
              ),
              SizedBox(
                height: 30,
                width: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () =>
                      _deletePayment(payment['id'].toString()),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 2 – MEMBER HISTORY (search → 12-month grid)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMemberHistoryTab() {
    final filteredMembers = _memberSearchQuery.isEmpty
        ? _members
        : _members.where((m) {
            final n = (m['full_name']?.toString() ?? '').toLowerCase();
            return n.contains(_memberSearchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() {
              _memberSearchQuery = v;
              if (v.isEmpty) _selectedMember = null;
            }),
            decoration: InputDecoration(
              hintText: 'Search member by name...',
              hintStyle:
                  GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        if (_selectedMember == null) ...[
          // Member list to pick from
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: filteredMembers.length,
              itemBuilder: (ctx, i) {
                final m = filteredMembers[i];
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (m['full_name']?.toString() ?? 'U')[0].toUpperCase(),
                        style: GoogleFonts.outfit(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(m['full_name'] ?? 'Unknown',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    subtitle: Text(m['phone']?.toString() ?? '',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textMuted),
                    onTap: () => setState(() => _selectedMember = m),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          // Year selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _selectedYear--)),
                Text('$_selectedYear',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _selectedYear++)),
                const SizedBox(width: 16),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                  onPressed: () => setState(() => _selectedMember = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Member name
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Text(
                  (_selectedMember!['full_name']?.toString() ?? 'U')[0]
                      .toUpperCase(),
                  style: GoogleFonts.outfit(
                      color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Text(_selectedMember!['full_name'] ?? 'Unknown',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
          ),

          // 12-month grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                itemCount: 12,
                itemBuilder: (ctx, idx) {
                  final mCode = _monthNames[idx];
                  final payment = _findPayment(
                      _selectedMember!['id'], mCode, _selectedYear);

                  Color bg = Colors.grey.shade100;
                  Color fg = Colors.grey.shade500;
                  String label = 'Missing';
                  String sub = '';

                  if (payment != null) {
                    final s =
                        payment['status']?.toString().toLowerCase() ?? '';
                    if (s == 'paid') {
                      bg = AppColors.success.withOpacity(0.12);
                      fg = AppColors.success;
                      label = 'Paid';
                      sub = 'KES ${payment['amount'] ?? 0}';
                    } else if (s == 'pending') {
                      bg = AppColors.warning.withOpacity(0.12);
                      fg = Colors.orange.shade800;
                      label = 'Pending';
                    } else if (s == 'late') {
                      bg = AppColors.error.withOpacity(0.12);
                      fg = AppColors.error;
                      label = 'Late';
                    }
                  }

                  return InkWell(
                    onTap: () => _editGridPayment(
                        _selectedMember!, mCode, _selectedYear, payment),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: fg.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(mCode,
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: fg)),
                          const SizedBox(height: 4),
                          Text(label,
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: fg)),
                          if (sub.isNotEmpty)
                            Text(sub,
                                style: GoogleFonts.outfit(
                                    fontSize: 9, color: fg)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Map<String, dynamic>? _findPayment(dynamic memberId, String mCode, int year) {
    try {
      return _payments.firstWhere((p) {
        if (p['member_id']?.toString() != memberId?.toString()) return false;
        final m = (p['month']?.toString() ?? '').toLowerCase();
        return m.startsWith(mCode.toLowerCase()) &&
            m.contains(year.toString());
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _editGridPayment(Map<String, dynamic> member, String mCode,
      int year, Map<String, dynamic>? existing) async {
    final fullMonth = '$mCode $year';
    final amtCtrl =
        TextEditingController(text: existing?['amount']?.toString() ?? '500');
    String status =
        existing?['status']?.toString().toLowerCase() ?? 'paid';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('$fullMonth Payment',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Amount (KES)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: ['pending', 'paid', 'late'].contains(status)
                  ? status
                  : 'paid',
              decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'late', child: Text('Late')),
              ],
              onChanged: (v) => setD(() => status = v!),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    setState(() => _isLoading = true);
    try {
      final amount = int.tryParse(amtCtrl.text) ?? 0;
      if (existing != null) {
        await SupabaseService.adminUpdatePayment(existing['id'], {
          'status': status,
          'amount': amount,
          'payment_date': DateTime.now().toIso8601String().substring(0, 10),
        });
      } else {
        await SupabaseService.adminAddPayment({
          'member_id': member['id'],
          'member_name': member['full_name'] ?? 'Unknown',
          'amount': amount,
          'month': fullMonth,
          'payment_type': 'Monthly Contribution',
          'status': status,
          'payment_date': DateTime.now().toIso8601String().substring(0, 10),
        });
      }
      await _loadData();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 3 – BULK ACTIONS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBulkActionsTab() {
    final filteredMembers = _bulkSearch.isEmpty
        ? _members
        : _members.where((m) {
            final n = (m['full_name']?.toString() ?? '').toLowerCase();
            return n.contains(_bulkSearch.toLowerCase());
          }).toList();

    return Column(
      children: [
        // Config area
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _bulkAmountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Amount (KES)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _bulkStatus,
                    decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        isDense: true),
                    items: const [
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'late', child: Text('Late')),
                    ],
                    onChanged: (v) => setState(() => _bulkStatus = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _bulkType,
                    decoration: InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        isDense: true),
                    items: const [
                      DropdownMenuItem(
                          value: 'Monthly Contribution',
                          child: Text('Monthly Contribution')),
                      DropdownMenuItem(
                          value: 'Registration Fee',
                          child: Text('Registration Fee')),
                      DropdownMenuItem(
                          value: 'Penalty', child: Text('Penalty')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _bulkType = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary)),
                          child: child!,
                        ),
                      );
                      if (d != null) {
                        setState(() => _bulkMonth = '${_monthNames[d.month - 1]} ${d.year}');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              _bulkMonth.isEmpty ? 'Select Month' : 'Month: $_bulkMonth',
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: _bulkMonth.isEmpty
                                      ? Colors.grey.shade600
                                      : Colors.black)),
                          const Icon(Icons.calendar_month, size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),

        // Search + Toggle All
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _bulkSearch = v),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon:
                      const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.checklist, size: 18),
              label: const Text('All'),
              onPressed: () {
                final ids =
                    filteredMembers.map((e) => e['id'].toString()).toSet();
                setState(() {
                  if (_bulkSelectedIds.containsAll(ids)) {
                    _bulkSelectedIds.removeAll(ids);
                  } else {
                    _bulkSelectedIds.addAll(ids);
                  }
                });
              },
            ),
          ]),
        ),

        // Counter
        if (_bulkSelectedIds.isNotEmpty)
          Container(
            color: AppColors.primary.withOpacity(0.06),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.group, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('${_bulkSelectedIds.length} members selected',
                    style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),

        // Member list
        Expanded(
          child: ListView.builder(
            itemCount: filteredMembers.length,
            itemBuilder: (ctx, i) {
              final m = filteredMembers[i];
              final id = m['id'].toString();
              final isSelected = _bulkSelectedIds.contains(id);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _bulkSelectedIds.add(id);
                    } else {
                      _bulkSelectedIds.remove(id);
                    }
                  });
                },
                title: Text(m['full_name'] ?? 'Unknown',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(m['phone']?.toString() ?? '',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textSecondary)),
                activeColor: AppColors.primary,
                secondary: CircleAvatar(
                  radius: 16,
                  backgroundColor: isSelected
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.grey.shade100,
                  child: Text(
                    (m['full_name']?.toString() ?? 'U')[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                        color:
                            isSelected ? AppColors.primary : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              );
            },
          ),
        ),

        // Submit button
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bulkSelectedIds.isEmpty
                        ? Colors.grey.shade300
                        : AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed:
                      _bulkSelectedIds.isEmpty ? null : _submitBulkPayments,
                  icon: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                  label: Text(
                    _bulkSelectedIds.isEmpty
                        ? 'Select members to continue'
                        : 'Add Payment to ${_bulkSelectedIds.length} Members',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bulkSelectedIds.isEmpty
                        ? Colors.grey.shade300
                        : AppColors.purple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed:
                      _bulkSelectedIds.isEmpty ? null : _issueBulkPayout,
                  icon: const Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 20),
                  label: Text(
                    'Issue Savings Payout (${_bulkSelectedIds.length})',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _issueBulkPayout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payout'),
        content: Text('Are you sure you want to mark all savings for ${_bulkSelectedIds.length} members as paid out? This will reset their savings balances to zero.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Payout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    int updatedCount = 0;
    
    try {
      final allPayments = await SupabaseService.adminFetchAllPayments();
      final userId = SupabaseService.currentUser?.id;

      for (final memberId in _bulkSelectedIds) {
        final memberName = _members.firstWhere((m) => m['id'].toString() == memberId, orElse: () => {})['full_name'] ?? 'Unknown';
        double memberPayoutSum = 0;

        final paymentsToUpdate = allPayments.where((p) {
          final isSameMember = p['member_id'].toString() == memberId.toString();
          final isPaid = (p['status'] ?? '').toString().toLowerCase() == 'paid';
          final type = (p['payment_type'] ?? p['type'] ?? '').toString().toLowerCase();
          final isReg = type.contains('reg') || type.contains('registration');
          final isAccumulating = (p['payout_status'] ?? '').toString().toLowerCase() != 'paid_out';
          
          return isSameMember && isPaid && !isReg && isAccumulating;
        }).toList();
        
        for(final payment in paymentsToUpdate) {
           final amt = num.tryParse(payment['amount']?.toString() ?? '0')?.toDouble() ?? 0.0;
           memberPayoutSum += amt;
           await SupabaseService.adminUpdatePayment(payment['id'].toString(), {'payout_status': 'paid_out'});
           updatedCount++;
        }
        
        // Auto-record to Organization Expenses if sum > 0
        if (memberPayoutSum > 0) {
           await SupabaseService.adminAddExpense({
             'amount': memberPayoutSum,
             'description': 'End of Year Payout: $memberName',
             'type': 'payout',
             'status': 'approved', // Automatically approved since admin issued it
             'added_by': userId,
           });
        }
      }
      
      _bulkSelectedIds.clear();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Issued payout for $updatedCount payment records'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch(e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _submitBulkPayments() async {
    final amount = int.tryParse(_bulkAmountCtrl.text) ?? 0;
    setState(() => _isLoading = true);
    int added = 0;
    try {
      int skipped = 0;
      for (final memberId in _bulkSelectedIds) {
        // Skip if duplicate exists
        final duplicate = _payments.any((p) =>
            p['member_id']?.toString() == memberId &&
            (p['month']?.toString().toLowerCase() ?? '') == _bulkMonth.toLowerCase() &&
            (p['payment_type']?.toString().toLowerCase() ?? '') == _bulkType.toLowerCase());
        if (duplicate) {
          skipped++;
          continue;
        }
        final memberName = _members.firstWhere(
            (m) => m['id'].toString() == memberId,
            orElse: () => {})['full_name'] ?? 'Unknown';
        await SupabaseService.adminAddPayment({
          'member_id': memberId,
          'member_name': memberName,
          'amount': amount,
          'month': _bulkMonth,
          'payment_type': _bulkType,
          'status': _bulkStatus,
          'payment_date': DateTime.now().toIso8601String().substring(0, 10),
        });
        added++;
      }
      _bulkSelectedIds.clear();
      await _loadData();
      if (mounted) {
        if (skipped > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Added $added payments. ⚠️ Skipped $skipped duplicates.'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Successfully added $added payments'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStatBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700, color: color, fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.outfit(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TAB 4 – SUMMARY
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSummaryTab() {
    final filteredMembers = _summarySearchQuery.isEmpty
        ? _members
        : _members.where((m) {
            final n = (m['full_name']?.toString() ?? '').toLowerCase();
            return n.contains(_summarySearchQuery.toLowerCase());
          }).toList();

    // Calculate totals
    final List<Map<String, dynamic>> summaryData = [];
    for (var member in filteredMembers) {
      final memberId = member['id'];
      final memberPayments = _payments.where((p) =>
          p['member_id'] == memberId &&
          (p['status']?.toString().toLowerCase() ?? '') == 'completed');

      double totalAmount = 0.0;
      int paymentCount = 0;

      for (var p in memberPayments) {
        final amountStr = p['amount']?.toString() ?? '0';
        totalAmount += double.tryParse(amountStr) ?? 0.0;
        paymentCount++;
      }

      summaryData.add({
        'member': member,
        'total': totalAmount,
        'count': paymentCount,
      });
    }

    // Sort by total descending
    summaryData.sort((a, b) =>
        (b['total'] as double).compareTo(a['total'] as double));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (v) => setState(() => _summarySearchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search members...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ),
        Expanded(
          child: summaryData.isEmpty
              ? Center(
                  child: Text('No members found',
                      style: GoogleFonts.outfit(color: AppColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: summaryData.length,
                  itemBuilder: (context, index) {
                    final data = summaryData[index];
                    final member = data['member'];
                    final total = data['total'] as double;
                    final count = data['count'] as int;

                    Color amountColor = AppColors.primary;
                    if (total >= 10000) {
                      amountColor = Colors.green.shade700;
                    } else if (total >= 5000) {
                      amountColor = Colors.orange.shade700;
                    } else if (total < 1000) {
                      amountColor = AppColors.red;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(
                              (member['full_name']?.toString() ?? '?')
                                  .characters
                                  .first
                                  .toUpperCase(),
                              style: GoogleFonts.outfit(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member['full_name'] ?? 'Unknown',
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(member['email'] ?? '',
                                    style: GoogleFonts.outfit(
                                        color: AppColors.textMuted,
                                        fontSize: 13)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('$count payments',
                                      style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total Paid',
                                  style: GoogleFonts.outfit(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                              Text(
                                '\$${total.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  color: amountColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
