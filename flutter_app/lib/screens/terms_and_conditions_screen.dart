import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  static const String route = '/terms-and-conditions';

  const TermsAndConditionsScreen({Key? key}) : super(key: key);

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  bool _hasAgreed = false;
  String? _agreedAtDate;
  bool _isSavingAgreement = false;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _loadAgreementStatus();
  }

  Future<void> _loadAgreementStatus() async {
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final localAgreed = prefs.getBool('welfare_rules_agreed_${user.id}') ?? false;
        final localDate = prefs.getString('welfare_rules_agreed_date_${user.id}');

        if (localAgreed) {
          if (mounted) {
            setState(() {
              _hasAgreed = true;
              _agreedAtDate = localDate;
            });
          }
        } else {
          // Check from Firestore member document
          final member = await SupabaseService.fetchCurrentMember();
          if (member != null && mounted) {
            final fd = (member['form_details'] as Map<String, dynamic>?) ?? {};
            final cloudAgreed = (fd['agreed_to_welfare_rules'] == true) ||
                (member['agreed_to_welfare_rules'] == true);
            final cloudDate = (fd['welfare_rules_agreed_at'] ?? member['welfare_rules_agreed_at'])?.toString();

            if (cloudAgreed) {
              setState(() {
                _hasAgreed = true;
                _agreedAtDate = cloudDate;
              });
              await prefs.setBool('welfare_rules_agreed_${user.id}', true);
              if (cloudDate != null) {
                await prefs.setString('welfare_rules_agreed_date_${user.id}', cloudDate);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading agreement status: $e');
    }
  }

  Future<void> _toggleAgreement(bool? value) async {
    final newValue = value ?? false;
    final user = SupabaseService.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'Agreed! Please log in to permanently record your signature.'
                : 'Agreement unchecked.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      setState(() => _hasAgreed = newValue);
      return;
    }

    setState(() => _isSavingAgreement = true);
    try {
      final nowStr = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('welfare_rules_agreed_${user.id}', newValue);
      if (newValue) {
        await prefs.setString('welfare_rules_agreed_date_${user.id}', nowStr);
      } else {
        await prefs.remove('welfare_rules_agreed_date_${user.id}');
      }

      await SupabaseService.updateMember(user.id, {
        'agreed_to_welfare_rules': newValue,
        'welfare_rules_agreed_at': newValue ? nowStr : null,
        'form_details.agreed_to_welfare_rules': newValue,
        'form_details.welfare_rules_agreed_at': newValue ? nowStr : null,
      });

      if (mounted) {
        setState(() {
          _hasAgreed = newValue;
          _agreedAtDate = newValue ? nowStr : null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? '✅ You have officially accepted the Benevolent Welfare Constitution.'
                  : '⚠️ Agreement status updated.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            backgroundColor: newValue ? AppColors.success : AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving agreement: $e');
      if (mounted) {
        setState(() => _hasAgreed = newValue);
      }
    } finally {
      if (mounted) setState(() => _isSavingAgreement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Benevolent Welfare Constitution',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Official Policies & Code of Conduct',
              style: GoogleFonts.outfit(
                color: AppColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18.0, 20.0, 18.0, 36.0 + MediaQuery.of(context).padding.bottom),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── HERO HEADER BANNER ──────────────────────────────────────────
            _buildHeroHeader(),
            const SizedBox(height: 20),

            // ─── GUIDING SCRIPTURE CARD ──────────────────────────────────────
            _buildScriptureCard(),
            const SizedBox(height: 22),

            // ─── CORE PRINCIPLES WITH NICE UNDERLINING ───────────────────────
            _buildCorePrinciplesSection(),
            const SizedBox(height: 24),

            // ─── KEY FINANCIAL NUMBERS / AT A GLANCE ────────────────────────
            _buildFinancialHighlights(),
            const SizedBox(height: 28),

            // ─── SEARCH / FILTER BOX ─────────────────────────────────────────
            _buildSearchBox(),
            const SizedBox(height: 20),

            // ─── MINUTES & ADOPTION NOTICE ───────────────────────────────────
            _buildMinutesMetadataCard(),
            const SizedBox(height: 22),

            // ─── DETAILED CONSTITUTION ARTICLES ──────────────────────────────
            ..._buildConstitutionClauses(),

            const SizedBox(height: 24),

            // ─── CONFIRMATION & SIGNATURES CARD ──────────────────────────────
            _buildSignaturesCard(),

            const SizedBox(height: 30),

            // ─── INTERACTIVE ACCEPTANCE & ABIDE SECTION ──────────────────────
            _buildAgreementSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HERO HEADER
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF1E6FD9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold.withOpacity(0.6)),
                      ),
                      child: Text(
                        'OFFICIAL GOVERNING CHARTER',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OneFellowship Welfare Fund',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Formally deliberated, approved, and enacted during the Benevolent Meeting to protect all members, maintain transparent stewardship, and guarantee emergency solidarity.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white.withOpacity(0.92),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // GUIDING SCRIPTURE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildScriptureCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.format_quote_rounded, color: Color(0xFFD97706), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guiding Scripture',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '“Let all things be done decently and in order.”',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1st Corinthians 14:40 (Amen)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CORE PRINCIPLES
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCorePrinciplesSection() {
    final principles = [
      {'title': 'Transparency & Accountability', 'icon': Icons.visibility_rounded, 'color': Color(0xFF0B4FBB)},
      {'title': 'Unity & Mutual Support', 'icon': Icons.diversity_3_rounded, 'color': Color(0xFF0D9488)},
      {'title': 'Integrity & Responsible Leadership', 'icon': Icons.verified_user_rounded, 'color': Color(0xFFD97706)},
      {'title': 'Respect for Members & Officials', 'icon': Icons.handshake_rounded, 'color': Color(0xFF7C3AED)},
      {'title': 'Collective Decision Making', 'icon': Icons.how_to_vote_rounded, 'color': Color(0xFF2563EB)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'General Benevolent Welfare Principles',
          subtitle: 'The foundational ethos guiding every welfare decision and action',
          icon: Icons.stars_rounded,
          accentColor: AppColors.primary,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: principles.map((p) {
            final color = p['color'] as Color;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p['icon'] as IconData, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    p['title'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // FINANCIAL HIGHLIGHTS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFinancialHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Financial Parameters & Key Deadlines',
          subtitle: 'Enforceable monetary thresholds and statutory notice periods',
          icon: Icons.payments_rounded,
          accentColor: const Color(0xFF10B981),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Commitment Fee',
                value: 'KES 1,000',
                note: 'One-time per case • Strictly non-refundable',
                color: AppColors.primary,
                icon: Icons.badge_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Min. Contribution',
                value: 'KES 1,000',
                note: 'Applies equally per member',
                color: const Color(0xFF10B981),
                icon: Icons.savings_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Triple Authorization',
                value: '3 Sign-Offs',
                note: 'Chair + Secretary + Treasurer required',
                color: const Color(0xFFD97706),
                icon: Icons.lock_person_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Default Grace Period',
                value: '7 Days',
                note: '2 consecutive misses = Termination',
                color: AppColors.danger,
                icon: Icons.timer_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String note,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              color: AppColors.textMuted,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEARCH BOX
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
        style: GoogleFonts.outfit(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search clauses (e.g., funeral, fraud, kin, appeal, 1000)...',
          hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
          suffixIcon: _searchFilter.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _searchFilter = ''),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MINUTES METADATA CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMinutesMetadataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.primaryDark, size: 20),
              const SizedBox(width: 8),
              Text(
                'Policy Adoption & Enactment',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'RATIFIED',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Formally Adopted on Friday 6th November 2026',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Official welfare constitution and binding policies enacted to govern member registration, commitment contributions, emergency allocations, and financial stewardship.',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CONSTITUTION CLAUSES
  // ───────────────────────────────────────────────────────────────────────────
  List<Widget> _buildConstitutionClauses() {
    final clauses = [
      {
        'number': '1',
        'title': 'Membership Registration & Qualification',
        'icon': Icons.how_to_reg_rounded,
        'accent': const Color(0xFF0B4FBB),
        'summary': 'Mandatory legal identification and onboarding prerequisites',
        'items': [
          'Every registered member shall provide their full legal names and active contact details.',
          'Every member must designate their Next of Kin, providing verified full names, active phone contact, and unique national identification (National ID card number or Birth Certificate number).',
          'A verifiable copy / record of National ID card, Birth Certificate, or other government-issued identification document is mandatory for all members and next of kin.',
          'The Welfare Committee reserves the right to request any other document deemed necessary for audit and identity validation.',
          'Membership status shall only become ACTIVE upon full completion of registration requirements and upfront payment of the commitment fee.',
        ],
      },
      {
        'number': '2',
        'title': 'Commitment Fee Policy',
        'icon': Icons.account_balance_wallet_rounded,
        'accent': const Color(0xFF0284C7),
        'summary': 'One-time onboarding and case protection fee',
        'items': [
          'A one-time membership commitment fee of KES 1,000 per case is instituted for all active members.',
          'The commitment fee is STRICTLY NON-REFUNDABLE under all circumstances.',
          'All contributions must be paid upfront within the stipulated timelines communicated by the committee.',
          'The contribution amount shall apply equally to all eligible welfare cases unless amended through an approved resolution of members.',
        ],
      },
      {
        'number': '3',
        'title': 'Minimum Proposed Contribution',
        'icon': Icons.monetization_on_rounded,
        'accent': const Color(0xFF059669),
        'summary': 'Floor contribution per member across all welfare calls',
        'items': [
          'The agreed minimum statutory contribution per member is KES 1,000.',
          'Members are free to contribute voluntary sums above the KES 1,000 threshold to assist distressed brethren.',
          'No contribution below KES 1,000 shall be accepted as satisfying a member’s welfare obligation.',
        ],
      },
      {
        'number': '4',
        'title': 'Members Covered Under the Welfare Fund',
        'icon': Icons.family_restroom_rounded,
        'accent': const Color(0xFF7C3AED),
        'summary': 'Scope of eligible beneficiaries',
        'items': [
          'The registered member.',
          'Their legally recognized spouse.',
          'Their biological or legally adopted children.',
          'Their biological parents.',
          'STRICT BENEFIT CLAUSE: Only persons declared during official member registration or officially updated thereafter through formal notification shall qualify for welfare benefits.',
        ],
      },
      {
        'number': '5',
        'title': 'Occasions Covered & Application Timelines',
        'icon': Icons.event_available_rounded,
        'accent': const Color(0xFFD97706),
        'summary': 'Qualifying events and mandatory advance notice periods',
        'items': [
          'Bereavement & Funeral Support: Official notification must be submitted AT LEAST 3 DAYS before the scheduled burial.',
          'Weddings & Other Approved Occasions: Formal welfare request must be lodged AT LEAST 2 WEEKS before the wedding date.',
          'Other Emergencies: Medical crises or unforeseen distress situations as formally reviewed and agreed upon by the members.',
        ],
      },
      {
        'number': '6',
        'title': 'Authorization of Transactions (Financial Control)',
        'icon': Icons.security_rounded,
        'accent': const Color(0xFFDC2626),
        'summary': 'Mandatory multi-signature controls & anti-fraud safeguards',
        'items': [
          'TRIPLE AUTHORIZATION RULE: All withdrawals, payments, and disbursements from the welfare fund MUST be jointly authorized by: 1. Chairperson, 2. Secretary, and 3. Treasurer.',
          'NO INDEPENDENT ACTION: No single official shall independently authorize withdrawal or disbursement of welfare funds under any circumstance.',
          'DOCUMENTATION MANDATE: All financial transactions must be properly documented, verified, and supported by receipts and official bank/M-Pesa records.',
          'Any transaction failing triple sign-off is null, void, and subject to immediate freeze.',
        ],
      },
      {
        'number': '7',
        'title': 'Disciplinary Measures & Membership Termination',
        'icon': Icons.gavel_rounded,
        'accent': const Color(0xFFEA580C),
        'summary': 'Penalties for default, late remittance, and due process',
        'items': [
          'TERMINATION FOR DEFAULT: A member who fails to submit contributions for two (2) consecutive welfare cases shall be liable to immediate termination of membership.',
          'GRACE PERIOD: Any late submission will be granted a statutory grace period of 7 days from the due date before penalty triggers.',
          'NEXT OF KIN NOTIFICATION: The member’s registered next of kin shall be formally notified when termination proceedings arise.',
          'OFFICIAL MISCONDUCT: Any official found engaging in misconduct, abuse of office, or negligence to the welfare constitution shall face immediate suspension from official duties pending disciplinary proceedings.',
          'RIGHT OF APPEAL: The affected official or member shall have the constitutional right to appeal the disciplinary decision within 7 days.',
          'FAIRNESS GUARANTEE: Disciplinary proceedings shall strictly uphold fairness, transparency, and the fundamental right of every accused person to be heard.',
        ],
      },
      {
        'number': '8',
        'title': 'Misappropriation, Fraud & Independent Audit',
        'icon': Icons.policy_rounded,
        'accent': const Color(0xFF991B1B),
        'summary': 'Strict protocol against embezzlement and financial malfeasance',
        'items': [
          'IMMEDIATE RESTRICTION: In case of any suspected embezzlement or misappropriation of funds, the Treasurer (or implicated official) shall immediately be restricted from accessing welfare accounts and funds pending investigation.',
          'INDEPENDENT AUDIT APPOINTMENT: An independent audit team shall be appointed immediately to investigate the allegations impartially.',
          'AUDIT REPORT: The investigation report shall establish final facts and evidence before any final determination is made.',
          'LEGAL ACTION: If found guilty, appropriate disciplinary, recovery, and criminal legal action shall be taken in accordance with the constitution and the laws of Kenya.',
          'SELECTION BY CHURCH: The entire church membership shall participate in the selection of the Audit and Disciplinary team.',
          'INDEPENDENCE: The Disciplinary Committee is an autonomous body responsible for examining financial records, transactions, accountability, and the general financial health of the welfare fund.',
        ],
      },
    ];

    final filtered = clauses.where((c) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter;
      final title = (c['title'] as String).toLowerCase();
      final summary = (c['summary'] as String).toLowerCase();
      final items = (c['items'] as List<String>).join(' ').toLowerCase();
      return title.contains(q) || summary.contains(q) || items.contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 8),
              Text(
                'No clauses match "$_searchFilter"',
                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ];
    }

    return filtered.map((clause) {
      final accent = clause['accent'] as Color;
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.15), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clause Header with color band
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.06),
                border: Border(bottom: BorderSide(color: accent.withOpacity(0.12))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      clause['number'] as String,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clause['title'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        // Underline accent indicator
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          height: 2.5,
                          width: 40,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(clause['icon'] as IconData, color: accent, size: 22),
                ],
              ),
            ),

            // Subtitle / Summary
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Text(
                clause['summary'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            // Clauses list
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: Column(
                children: (clause['items'] as List<String>).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Icon(Icons.circle, size: 7, color: accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF334155),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SIGNATURES & CONFIRMATION
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSignaturesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Executive Governance & Ratification',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Underline
          Container(
            height: 2,
            width: 50,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This constitution and its disciplinary policies were formally approved and adopted on Friday 6th November 2026 as the binding rules for all members and elected leadership.',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSignatureBox(
                  role: 'OFFICE OF CHAIRPERSON',
                  name: 'Executive Chairperson',
                  title: 'Welfare Leadership Council',
                  icon: Icons.shield_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSignatureBox(
                  role: 'OFFICE OF SECRETARY',
                  name: 'Executive Secretary',
                  title: 'Welfare Documentation Office',
                  icon: Icons.edit_document,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBox({
    required String role,
    required String name,
    required String title,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                role,
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 12, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'CONFIRMED',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // INTERACTIVE ACCEPTANCE & ABIDE SECTION
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAgreementSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _hasAgreed ? AppColors.success : AppColors.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_hasAgreed ? AppColors.success : AppColors.primary).withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_hasAgreed ? AppColors.success : AppColors.primary).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasAgreed ? Icons.verified_rounded : Icons.thumb_up_alt_rounded,
                  color: _hasAgreed ? AppColors.success : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Adherence Affirmation',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _hasAgreed
                          ? 'You are in good standing & bound by this constitution'
                          : 'Mandatory for all active fellowship participants',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _hasAgreed ? AppColors.success : AppColors.textSecondary,
                        fontWeight: _hasAgreed ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _hasAgreed,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: _isSavingAgreement ? null : _toggleAgreement,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _isSavingAgreement ? null : () => _toggleAgreement(!_hasAgreed),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'I have carefully read, fully understood, and solemnly agree to abide by all the rules, contributions, deadlines, and disciplinary measures of the OneFellowship Benevolent Welfare Fund.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
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
          ),
          if (_hasAgreed && _agreedAtDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Affirmed & signed digitally: ${_formatDate(_agreedAtDate!)}',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 8),
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
        const SizedBox(height: 4),
        Container(
          height: 2.5,
          width: 36,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
