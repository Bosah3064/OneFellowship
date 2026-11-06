import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../services/supabase_service.dart';
import 'dashboard_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  static const route = '/complete-profile';

  final bool isMandatory;

  const CompleteProfileScreen({
    super.key,
    this.isMandatory = false,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal controllers
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();

  // Next of kin controllers
  final _nokNameCtrl = TextEditingController();
  final _nokPhoneCtrl = TextEditingController();
  final _nokIdCtrl = TextEditingController();

  // Dropdown selections
  String? _gender;
  String? _maritalStatus;
  String? _branch;
  String? _relationship;
  String _hasDependants = 'No';
  final _dependantsCountCtrl = TextEditingController(text: '0');

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final List<String> _maritalOptions = [
    'Single',
    'Married',
    'Divorced',
    'Widowed',
  ];

  final List<String> _branchOptions = [
    'Nairobi',
    'Mombasa',
    'Kisumu',
    'Nakuru',
    'Eldoret',
    'Thika',
    'Machakos',
    'Meru',
    'Nyeri',
    'Diaspora',
    'Other Chapter',
  ];

  final List<String> _relationshipOptions = [
    'Spouse',
    'Child',
    'Parent',
    'Sibling',
    'Guardian',
    'Relative',
    'Friend',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _idNumberCtrl.dispose();
    _dobCtrl.dispose();
    _occupationCtrl.dispose();
    _nokNameCtrl.dispose();
    _nokPhoneCtrl.dispose();
    _nokIdCtrl.dispose();
    _dependantsCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _isLoading = true);
    try {
      final member = await SupabaseService.fetchCurrentMember();
      if (member != null && mounted) {
        _fullNameCtrl.text = (member['full_name'] ?? SupabaseService.currentUser?.displayName ?? '').toString();
        _phoneCtrl.text = (member['phone'] ?? '').toString();

        final fd = (member['form_details'] as Map<String, dynamic>?) ?? {};
        _idNumberCtrl.text = (fd['national_id_number'] ?? fd['id_number'] ?? '').toString();
        _dobCtrl.text = (fd['date_of_birth'] ?? fd['dob'] ?? '').toString();
        _occupationCtrl.text = (fd['occupation'] ?? '').toString();

        final g = fd['gender']?.toString();
        if (g != null && _genderOptions.contains(g)) _gender = g;

        final m = fd['marital_status']?.toString();
        if (m != null && _maritalOptions.contains(m)) _maritalStatus = m;

        final b = fd['branch']?.toString();
        if (b != null && _branchOptions.contains(b)) _branch = b;

        _nokNameCtrl.text = (fd['next_of_kin_full_name'] ?? fd['nok_name'] ?? '').toString();
        _nokPhoneCtrl.text = (fd['next_of_kin_phone_number'] ?? fd['nok_phone'] ?? '').toString();
        _nokIdCtrl.text = (fd['next_of_kin_national_id_number'] ?? fd['nok_id'] ?? '').toString();

        final r = fd['relationship_to_you']?.toString();
        if (r != null && _relationshipOptions.contains(r)) _relationship = r;

        final hd = fd['has_dependants']?.toString();
        if (hd == 'Yes' || hd == 'true') {
          _hasDependants = 'Yes';
          _dependantsCountCtrl.text = (fd['number_of_dependants'] ?? '1').toString();
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 25, 1, 1);
    final firstDate = DateTime(now.year - 100);
    final lastDate = DateTime(now.year - 16);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _dobCtrl.text = '$y-$m-$d';
      });
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please correct the highlighted fields before saving.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final user = SupabaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please sign in again.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final idVal = _idNumberCtrl.text.trim();
      final nokNameVal = _nokNameCtrl.text.trim();
      final nokPhoneVal = _nokPhoneCtrl.text.trim();
      final depCountVal = _hasDependants == 'Yes' ? _dependantsCountCtrl.text.trim() : '0';

      final formDetails = <String, dynamic>{
        'national_id_number': idVal,
        'id_number': idVal,
        'date_of_birth': _dobCtrl.text.trim(),
        'dob': _dobCtrl.text.trim(),
        'gender': _gender ?? '',
        'marital_status': _maritalStatus ?? '',
        'branch': _branch ?? '',
        'occupation': _occupationCtrl.text.trim(),
        'profession': _occupationCtrl.text.trim(),
        'next_of_kin_full_name': nokNameVal,
        'next_of_kin_name': nokNameVal,
        'nok_name': nokNameVal,
        'next_of_kin_phone_number': nokPhoneVal,
        'next_of_kin_phone': nokPhoneVal,
        'nok_phone': nokPhoneVal,
        'next_of_kin_national_id_number': _nokIdCtrl.text.trim(),
        'relationship_to_you': _relationship ?? '',
        'has_dependants': _hasDependants,
        'dependants': _hasDependants,
        'number_of_dependants': depCountVal,
        'dependant_count': depCountVal,
        'is_profile_complete': true,
        'completed_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.saveProfileDetails(
        user.id,
        phone: _phoneCtrl.text.trim(),
        fullName: _fullNameCtrl.text.trim(),
        formDetails: formDetails,
      );

      // Lock profile completion in local storage permanently
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('profile_completed_${user.id}', true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Profile submitted & verified! Welcome to OneFellowship.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Clear navigation backstack completely to prevent any accidental back-navigation to login or register
        Navigator.pushNamedAndRemoveUntil(context, DashboardScreen.route, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecor(String label, IconData icon, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2F7),
      appBar: AppBar(
        title: Text(
          'Membership Registration Form',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.isMandatory,
        actions: [
          if (widget.isMandatory)
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, DashboardScreen.route);
              },
              child: Text(
                'Skip for now',
                style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
            ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? (screenWidth - 760) / 2 : 16,
                vertical: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Complete Your Member Profile',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Please provide your official details to activate full welfare and card benefits.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SECTION 1: Personal Details
                    _buildSectionCard(
                      title: '1. Personal Information',
                      icon: Icons.person_rounded,
                      children: [
                        TextFormField(
                          controller: _fullNameCtrl,
                          decoration: _inputDecor('Full Legal Name', Icons.badge_outlined),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecor('Mobile Phone Number', Icons.phone_android_rounded, hint: 'e.g. 0712345678'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _idNumberCtrl,
                          decoration: _inputDecor('National ID / Passport No.', Icons.credit_card_rounded, hint: 'e.g. 12345678'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'National ID is required' : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dobCtrl,
                                readOnly: true,
                                onTap: _selectDateOfBirth,
                                decoration: _inputDecor(
                                  'Date of Birth',
                                  Icons.cake_rounded,
                                  hint: 'YYYY-MM-DD',
                                  suffix: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Date of birth required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _gender,
                                decoration: _inputDecor('Gender', Icons.wc_rounded),
                                items: _genderOptions
                                    .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.outfit(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() => _gender = v),
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _maritalStatus,
                                decoration: _inputDecor('Marital Status', Icons.favorite_rounded),
                                items: _maritalOptions
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m, style: GoogleFonts.outfit(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() => _maritalStatus = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _branch,
                                decoration: _inputDecor('Branch / Chapter', Icons.location_city_rounded),
                                items: _branchOptions
                                    .map((b) => DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.outfit(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() => _branch = v),
                                validator: (v) => (v == null || v.isEmpty) ? 'Branch required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _occupationCtrl,
                          decoration: _inputDecor('Occupation / Profession', Icons.work_outline_rounded, hint: 'e.g. Business, Teacher, IT'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Occupation is required' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 2: Next of Kin
                    _buildSectionCard(
                      title: '2. Next of Kin Details',
                      icon: Icons.people_alt_rounded,
                      children: [
                        Text(
                          'Designated beneficiary in accordance with OneFellowship welfare policy.',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nokNameCtrl,
                          decoration: _inputDecor('Next of Kin Full Name', Icons.person_pin_rounded),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Next of kin name is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nokPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecor('Next of Kin Phone Number', Icons.phone_forwarded_rounded, hint: 'e.g. 0712345678'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Next of kin phone is required' : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _relationship,
                                decoration: _inputDecor('Relationship', Icons.handshake_rounded),
                                items: _relationshipOptions
                                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.outfit(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setState(() => _relationship = v),
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _nokIdCtrl,
                                decoration: _inputDecor('Next of Kin ID (Optional)', Icons.badge_rounded),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 3: Dependants
                    _buildSectionCard(
                      title: '3. Dependants Information',
                      icon: Icons.family_restroom_rounded,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Do you have registered dependants / children?',
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'No', label: Text('No')),
                                ButtonSegment(value: 'Yes', label: Text('Yes')),
                              ],
                              selected: {_hasDependants},
                              onSelectionChanged: (set) {
                                setState(() => _hasDependants = set.first);
                              },
                            ),
                          ],
                        ),
                        if (_hasDependants == 'Yes') ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _dependantsCountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecor('Number of Dependants', Icons.child_care_rounded, hint: 'e.g. 2'),
                            validator: (v) {
                              if (_hasDependants == 'Yes' && (v == null || v.trim().isEmpty)) {
                                return 'Please specify number of dependants';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 28),

                    // SUBMIT BUTTON
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Save & Submit Member Details',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 48),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

