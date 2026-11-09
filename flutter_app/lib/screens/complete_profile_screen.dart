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

class DependantItem {
  final TextEditingController nameCtrl;
  final TextEditingController ageCtrl;
  final TextEditingController idCtrl;
  String idType;
  String relationship;

  DependantItem({
    String name = '',
    String age = '',
    String idNumber = '',
    this.idType = 'Birth Certificate',
    this.relationship = 'Child',
  })  : nameCtrl = TextEditingController(text: name),
        ageCtrl = TextEditingController(text: age),
        idCtrl = TextEditingController(text: idNumber);

  void dispose() {
    nameCtrl.dispose();
    ageCtrl.dispose();
    idCtrl.dispose();
  }

  Map<String, dynamic> toMap() => {
    'name': nameCtrl.text.trim(),
    'age': ageCtrl.text.trim(),
    'id_number': idCtrl.text.trim(),
    'identification': idCtrl.text.trim(),
    'id_type': idType,
    'relationship': relationship,
  };
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dependant controllers & list
  List<DependantItem> _dependants = [];
  final List<String> _dependantIdTypeOptions = [
    'Birth Certificate',
    'National ID',
    'Nemis / School ID',
    'Passport / Alien ID',
  ];
  final List<String> _dependantRelationshipOptions = [
    'Child',
    'Spouse',
    'Parent',
    'Sibling',
    'Legal Ward',
  ];

  // Personal controllers
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();

  // Residential & location controllers (County, Sub-County, Ward, Village)
  final _countyCtrl = TextEditingController();
  final _subCountyCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();

  // Next of kin controllers
  final _nokNameCtrl = TextEditingController();
  final _nokPhoneCtrl = TextEditingController();
  final _nokIdCtrl = TextEditingController();
  String _nokIdType = 'National ID Card';

  // Welfare rules agreement
  bool _agreedToRules = false;

  final List<String> _nokIdTypeOptions = [
    'National ID Card',
    'Birth Certificate',
    'Passport',
    'Alien / Refugee ID',
  ];

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
    _countyCtrl.dispose();
    _subCountyCtrl.dispose();
    _wardCtrl.dispose();
    _villageCtrl.dispose();
    _nokNameCtrl.dispose();
    _nokPhoneCtrl.dispose();
    _nokIdCtrl.dispose();
    _dependantsCountCtrl.dispose();
    for (final d in _dependants) {
      d.dispose();
    }
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

        _countyCtrl.text = (fd['county'] ?? '').toString();
        _subCountyCtrl.text = (fd['sub_county'] ?? fd['subcounty'] ?? '').toString();
        _wardCtrl.text = (fd['ward'] ?? fd['word'] ?? '').toString();
        _villageCtrl.text = (fd['village'] ?? fd['estate'] ?? fd['residence'] ?? '').toString();

        final g = fd['gender']?.toString();
        if (g != null && _genderOptions.contains(g)) _gender = g;

        final m = fd['marital_status']?.toString();
        if (m != null && _maritalOptions.contains(m)) _maritalStatus = m;

        final b = fd['branch']?.toString();
        if (b != null && _branchOptions.contains(b)) _branch = b;

        _nokNameCtrl.text = (fd['next_of_kin_full_name'] ?? fd['nok_name'] ?? '').toString();
        _nokPhoneCtrl.text = (fd['next_of_kin_phone_number'] ?? fd['nok_phone'] ?? '').toString();
        _nokIdCtrl.text = (fd['next_of_kin_national_id_number'] ?? fd['nok_id'] ?? '').toString();

        final nokType = (fd['next_of_kin_id_type'] ?? fd['nok_id_type'])?.toString();
        if (nokType != null && _nokIdTypeOptions.contains(nokType)) {
          _nokIdType = nokType;
        }

        final cloudAgreed = (fd['agreed_to_welfare_rules'] == true) || (member['agreed_to_welfare_rules'] == true);
        if (cloudAgreed) {
          _agreedToRules = true;
        } else {
          final prefs = await SharedPreferences.getInstance();
          final localAgreed = prefs.getBool('welfare_rules_agreed_${member['id'] ?? ''}') ?? false;
          if (localAgreed) _agreedToRules = true;
        }

        final r = fd['relationship_to_you']?.toString();
        if (r != null && _relationshipOptions.contains(r)) _relationship = r;

        final hd = fd['has_dependants']?.toString();
        if (hd == 'Yes' || hd == 'true') {
          _hasDependants = 'Yes';
          _dependantsCountCtrl.text = (fd['number_of_dependants'] ?? '1').toString();

          final rawList = fd['dependants_list'] ?? fd['dependants_details'];
          if (rawList is List && rawList.isNotEmpty) {
            _dependants = rawList.map((item) {
              final m = (item as Map).cast<String, dynamic>();
              final type = m['id_type']?.toString();
              final rel = m['relationship']?.toString();
              return DependantItem(
                name: (m['name'] ?? '').toString(),
                age: (m['age'] ?? '').toString(),
                idNumber: (m['id_number'] ?? m['identification'] ?? '').toString(),
                idType: _dependantIdTypeOptions.contains(type) ? type! : 'Birth Certificate',
                relationship: _dependantRelationshipOptions.contains(rel) ? rel! : 'Child',
              );
            }).toList();
          } else {
            final count = int.tryParse(_dependantsCountCtrl.text) ?? 1;
            _dependants = List.generate(count > 0 ? count : 1, (_) => DependantItem());
          }
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
    if (!_agreedToRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ You must agree to abide by the Welfare Constitution & Rules to submit your registration.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

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
      if (_hasDependants == 'Yes') {
        if (_dependants.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add at least one registered dependant or select "No".')),
          );
          return;
        }
        for (int i = 0; i < _dependants.length; i++) {
          final dep = _dependants[i];
          if (dep.nameCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please enter Full Legal Name for Dependant #${i + 1}')),
            );
            return;
          }
          if (dep.ageCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please enter Age / Year of Birth for Dependant #${i + 1}')),
            );
            return;
          }
          if (dep.idCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please enter Verified ID / Birth Cert No. for Dependant #${i + 1}')),
            );
            return;
          }
        }
      }

      final idVal = _idNumberCtrl.text.trim();
      final nokNameVal = _nokNameCtrl.text.trim();
      final nokPhoneVal = _nokPhoneCtrl.text.trim();
      final depCountVal = _hasDependants == 'Yes' ? _dependants.length.toString() : '0';
      final countyVal = _countyCtrl.text.trim();
      final subCountyVal = _subCountyCtrl.text.trim();
      final wardVal = _wardCtrl.text.trim();
      final villageVal = _villageCtrl.text.trim();

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
        'county': countyVal,
        'sub_county': subCountyVal,
        'subcounty': subCountyVal,
        'ward': wardVal,
        'word': wardVal,
        'village': villageVal,
        'estate': villageVal,
        'residence': villageVal,
        'next_of_kin_full_name': nokNameVal,
        'next_of_kin_name': nokNameVal,
        'nok_name': nokNameVal,
        'next_of_kin_phone_number': nokPhoneVal,
        'next_of_kin_phone': nokPhoneVal,
        'nok_phone': nokPhoneVal,
        'next_of_kin_national_id_number': _nokIdCtrl.text.trim(),
        'next_of_kin_id': _nokIdCtrl.text.trim(),
        'nok_id': _nokIdCtrl.text.trim(),
        'next_of_kin_id_type': _nokIdType,
        'nok_id_type': _nokIdType,
        'agreed_to_welfare_rules': true,
        'welfare_rules_agreed_at': DateTime.now().toIso8601String(),
        'commitment_fee_amount': 1000,
        'min_contribution_amount': 1000,
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

      // Lock profile completion & rules agreement in local storage permanently
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('profile_completed_${user.id}', true);
      await prefs.setBool('welfare_rules_agreed_${user.id}', true);
      await prefs.setString('welfare_rules_agreed_date_${user.id}', DateTime.now().toIso8601String());

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
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Residential & Location Details',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _countyCtrl,
                                decoration: _inputDecor('County', Icons.map_outlined, hint: 'e.g. Kisii / Nairobi'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'County is required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _subCountyCtrl,
                                decoration: _inputDecor('Sub-County', Icons.holiday_village_outlined, hint: 'e.g. Kitutu Central'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Sub-County is required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _wardCtrl,
                                decoration: _inputDecor('Ward', Icons.apartment_rounded, hint: 'e.g. Nyanchwa / Bogusero'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ward is required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _villageCtrl,
                                decoration: _inputDecor('Village / Estate', Icons.home_work_outlined, hint: 'e.g. Gesonso / Milimani'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Village / Estate is required' : null,
                              ),
                            ),
                          ],
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
                              child: DropdownButtonFormField<String>(
                                value: _nokIdType,
                                decoration: _inputDecor('ID Doc Type', Icons.folder_shared_rounded),
                                items: _nokIdTypeOptions
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.outfit(fontSize: 12.5))))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _nokIdType = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nokIdCtrl,
                          decoration: _inputDecor(
                            'Verified Next of Kin ID / Birth Cert No.',
                            Icons.verified_user_rounded,
                            hint: 'e.g. 12345678 or BC/2021/45678',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Next of kin verified identification number is required';
                            }
                            if (v.trim().length < 4) {
                              return 'Enter a valid identification number (min 4 characters)';
                            }
                            final myId = _idNumberCtrl.text.trim().toLowerCase();
                            if (myId.isNotEmpty && v.trim().toLowerCase() == myId) {
                              return 'Next of kin ID cannot be identical to member\'s own ID';
                            }
                            return null;
                          },
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
                                setState(() {
                                  _hasDependants = set.first;
                                  if (_hasDependants == 'Yes' && _dependants.isEmpty) {
                                    _dependants.add(DependantItem());
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (_hasDependants == 'Yes') ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Constitution Clause 4: Only declared dependants with verified legal identification qualify for welfare benefits.',
                                    style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.blue.shade900, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._dependants.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final dep = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Dependant #${idx + 1}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_dependants.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                          tooltip: 'Remove Dependant',
                                          onPressed: () {
                                            setState(() {
                                              dep.dispose();
                                              _dependants.removeAt(idx);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: dep.nameCtrl,
                                    decoration: _inputDecor('Dependant Full Legal Name', Icons.person_rounded, hint: 'e.g. Brian Makori'),
                                    validator: (v) {
                                      if (_hasDependants == 'Yes' && (v == null || v.trim().isEmpty)) {
                                        return 'Dependant name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: dep.ageCtrl,
                                          decoration: _inputDecor('Age / Birth Year', Icons.cake_rounded, hint: 'e.g. 8 or 2018'),
                                          validator: (v) {
                                            if (_hasDependants == 'Yes' && (v == null || v.trim().isEmpty)) {
                                              return 'Age required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _dependantRelationshipOptions.contains(dep.relationship) ? dep.relationship : 'Child',
                                          decoration: _inputDecor('Relationship', Icons.group_outlined),
                                          items: _dependantRelationshipOptions
                                              .map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.outfit(fontSize: 13))))
                                              .toList(),
                                          onChanged: (v) {
                                            if (v != null) setState(() => dep.relationship = v);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _dependantIdTypeOptions.contains(dep.idType) ? dep.idType : 'Birth Certificate',
                                          decoration: _inputDecor('ID Type', Icons.folder_shared_outlined),
                                          items: _dependantIdTypeOptions
                                              .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.outfit(fontSize: 12))))
                                              .toList(),
                                          onChanged: (v) {
                                            if (v != null) setState(() => dep.idType = v);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: dep.idCtrl,
                                          decoration: _inputDecor('Verified ID / Cert No.', Icons.verified_rounded, hint: 'e.g. BC/2018/12345'),
                                          validator: (v) {
                                            if (_hasDependants == 'Yes' && (v == null || v.trim().isEmpty)) {
                                              return 'ID/Cert No. required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _dependants.add(DependantItem());
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                              label: Text(
                                '+ Add Another Dependant',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 4: Welfare Fund Constitution & Code of Conduct Agreement
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _agreedToRules ? AppColors.success : AppColors.primary,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_agreedToRules ? AppColors.success : AppColors.primary).withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _agreedToRules ? Icons.verified_rounded : Icons.gavel_rounded,
                                color: _agreedToRules ? AppColors.success : AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Welfare Constitution & Policies',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _agreedToRules,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setState(() => _agreedToRules = val ?? false);
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _agreedToRules = !_agreedToRules);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      'I solemnly agree to abide by all the rules, constitution, commitment fee (KES 1,000), minimum contribution (KES 1,000), 7-day grace period, and disciplinary guidelines of OneFellowship.',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/terms-and-conditions');
                              },
                              icon: const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
                              label: Text(
                                'Read Full Constitution & Minutes',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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

