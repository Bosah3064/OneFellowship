import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';
import 'dashboard_screen.dart';

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
  
  // Book navigation state
  bool _isBookOpen = false;
  bool _continuousScrollMode = false;
  int _currentPage = 0;
  late final PageController _pageController;

  final int _totalPages = 9;

  final List<String> _chapterTitles = [
    'Preamble & Guiding Principles',
    'Ch. 1: Membership Registration',
    'Ch. 2: Commitment Fee Policy',
    'Ch. 3: Minimum Contribution',
    'Ch. 4: Eligible Beneficiaries',
    'Ch. 5: Covered Occasions & Timelines',
    'Ch. 6: Transaction Authorization',
    'Ch. 7: Discipline & Anti-Fraud',
    'Ch. 8: Ratification & Affirmation',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadAgreementStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          // Non-blocking fetch with quick timeout
          try {
            final member = await SupabaseService.fetchCurrentMember().timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );
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
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error loading agreement status: $e');
    }
  }

  /// Permanently ratifies and locks the constitution agreement.
  Future<void> _performRatification() async {
    if (_hasAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Constitution is already signed, ratified, and locked.',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSavingAgreement = true);
    final nowStr = DateTime.now().toIso8601String();
    final user = SupabaseService.currentUser;

    try {
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('welfare_rules_agreed_${user.id}', true);
        await prefs.setString('welfare_rules_agreed_date_${user.id}', nowStr);

        // Background update to cloud
        SupabaseService.updateMember(user.id, {
          'agreed_to_welfare_rules': true,
          'welfare_rules_agreed_at': nowStr,
          'form_details.agreed_to_welfare_rules': true,
          'form_details.welfare_rules_agreed_at': nowStr,
        }).catchError((e) {
          debugPrint('Cloud sync error (locally cached): $e');
        });

        // Audit log trail
        SupabaseService.logAuditEvent(
          action: 'CONSTITUTION_RATIFIED',
          title: 'Constitution Ratified & Signed',
          description: 'Member officially signed and ratified the OneFellowship Constitution under 1st Corinthians 14:40.',
          category: 'governance',
          performedBy: user.email ?? 'Member',
          performedById: user.id,
        ).catchError((_) {});
      }

      if (mounted) {
        setState(() {
          _hasAgreed = true;
          _agreedAtDate = nowStr;
          _isSavingAgreement = false;
        });

        // Celebratory Ratification Modal with Return to Home option
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            backgroundColor: const Color(0xFFFAF7F0),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Branded Seal
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F172A),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFFD4AF37),
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ratification Sealed & Locked!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '“Let all things be done decently and in order.”\n— 1st Corinthians 14:40',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF059669)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your digital covenant has been permanently locked and recorded. You can still freely view all pages.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF065F46),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Direct Return to Home button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: const Color(0xFFD4AF37),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _returnToHome();
                    },
                    icon: const Icon(Icons.home_rounded, color: Color(0xFFD4AF37), size: 20),
                    label: Text(
                      'Done • Return to Home Page',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Continue Browsing Constitution',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving agreement: $e');
      if (mounted) setState(() => _isSavingAgreement = false);
    }
  }

  /// Directs user back to the Home page or pops to prior screen cleanly
  void _returnToHome() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, DashboardScreen.route, (route) => false);
    }
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      final next = _currentPage + 1;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        setState(() => _currentPage = next);
      }
    }
  }

  void _goToPrevPage() {
    if (_currentPage > 0) {
      final prev = _currentPage - 1;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          prev,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        setState(() => _currentPage = prev);
      }
    } else {
      setState(() => _isBookOpen = false);
    }
  }

  void _jumpToChapter(int index) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
    setState(() {
      _currentPage = index;
      _isBookOpen = true;
      _continuousScrollMode = false;
    });
  }

  void _openTableOfContents() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Constitution Table of Contents',
                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              ...List.generate(_totalPages, (i) {
                final isCurrent = _currentPage == i && _isBookOpen;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isCurrent ? AppColors.primary : const Color(0xFFF3F4F6),
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  title: Text(
                    _chapterTitles[i],
                    style: GoogleFonts.outfit(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _jumpToChapter(i);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welfare Constitution Book',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: [
                if (_hasAgreed) ...[
                  const Icon(Icons.lock_rounded, color: AppColors.success, size: 11),
                  const SizedBox(width: 4),
                  Text(
                    'Ratified & Locked • ',
                    style: GoogleFonts.outfit(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
                Text(
                  _continuousScrollMode
                      ? 'Continuous View'
                      : (_isBookOpen ? 'Chapter ${_currentPage + 1} of $_totalPages' : 'Official Sealed Volume'),
                  style: GoogleFonts.outfit(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_hasAgreed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  elevation: 0,
                ),
                onPressed: _returnToHome,
                icon: const Icon(Icons.home_rounded, color: Colors.white, size: 16),
                label: Text(
                  'Home',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Table of Contents',
            icon: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white),
            onPressed: _openTableOfContents,
          ),
          IconButton(
            tooltip: _continuousScrollMode ? 'Switch to Book View' : 'Switch to Scroll View',
            icon: Icon(
              _continuousScrollMode ? Icons.auto_stories_rounded : Icons.view_headline_rounded,
              color: AppColors.gold,
            ),
            onPressed: () {
              setState(() {
                _continuousScrollMode = !_continuousScrollMode;
                if (!_continuousScrollMode) {
                  _isBookOpen = true;
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _continuousScrollMode
            ? _buildContinuousScrollView()
            : (!_isBookOpen ? _buildBookCoverView() : _buildPagedBookView()),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // VIEW 1: THE MAJESTIC BOOK COVER VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBookCoverView() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Realistic Hardcover Book Presentation
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F254B), Color(0xFF081833), Color(0xFF040D1D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD4AF37), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.22),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Bookmark Ribbon Graphic
                  Positioned(
                    top: 0,
                    right: 32,
                    child: Container(
                      width: 28,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                        boxShadow: [
                          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.bookmark_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        // Embossed Crest Seal with Official Logo
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF142C57),
                            border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.auto_stories_rounded,
                                color: Color(0xFFD4AF37),
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Gold Sub-banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD4AF37)),
                          ),
                          child: Text(
                            'OFFICIAL RATIFIED GOVERNANCE',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFDE68A),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Book Title
                        Text(
                          'THE CONSTITUTION',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            color: const Color(0xFFFFFBEB),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '& WELFARE POLICIES',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            color: const Color(0xFFD4AF37),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ONEFELLOWSHIP BENEVOLENT FUND',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFD4AF37), thickness: 1, indent: 40, endIndent: 40),
                        const SizedBox(height: 14),

                        // Scripture quote on cover
                        Text(
                          '“Let all things be done decently and in order.”',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            color: const Color(0xFFFEF3C7),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1st Corinthians 14:40',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFD4AF37),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Book Details Pill Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_hasAgreed) ...[
                              _buildCoverBadge(Icons.lock_rounded, 'Ratified 🔒'),
                              const SizedBox(width: 8),
                            ],
                            _buildCoverBadge(Icons.menu_book, '9 Chapters'),
                            const SizedBox(width: 8),
                            _buildCoverBadge(Icons.calendar_month, 'Nov 2026'),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // OPEN BOOK BUTTON (Full width, generous, never squeezed)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: const Color(0xFF0B192C),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              elevation: 8,
                              shadowColor: const Color(0xFFD4AF37).withOpacity(0.5),
                            ),
                            onPressed: () {
                              setState(() {
                                _isBookOpen = true;
                                _currentPage = 0;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_stories_rounded, color: Color(0xFF0B192C), size: 24),
                                const SizedBox(width: 10),
                                Text(
                                  'CLICK TO OPEN BOOK',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_hasAgreed) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: AppColors.success, width: 1.8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              ),
                              onPressed: _returnToHome,
                              icon: const Icon(Icons.home_rounded, color: AppColors.success, size: 20),
                              label: Text(
                                'Return to Home Page',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Continuous View Alternative
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _continuousScrollMode = true;
                            });
                          },
                          icon: const Icon(Icons.view_headline_rounded, color: Colors.white70, size: 16),
                          label: Text(
                            'Or browse in Continuous Scroll view',
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 13),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // VIEW 2: THE PAGED BOOK SPREAD (SWIPEABLE PAGES + CHAPTER QUICK SELECTOR)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPagedBookView() {
    return Column(
      children: [
        // Quick Chapter Selector Strip (Prevents navigation hanging)
        Container(
          color: const Color(0xFF0B172A),
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _totalPages,
              itemBuilder: (ctx, i) {
                final isSelected = _currentPage == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      'Ch. ${i + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD4AF37),
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFD4AF37) : Colors.white24,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    onSelected: (_) => _jumpToChapter(i),
                  ),
                );
              },
            ),
          ),
        ),

        // The Page View
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _totalPages,
            physics: const PageScrollPhysics(),
            onPageChanged: (idx) {
              setState(() => _currentPage = idx);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F0), // Authentic book parchment paper tone
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2D6C5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Left Spine Crease Effect
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 14,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.12),
                                  Colors.black.withOpacity(0.04),
                                  Colors.transparent,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),

                        // Page Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chapter Top Ornament with Logo
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('⚜️ ', style: TextStyle(fontSize: 14)),
                                  ClipOval(
                                    child: Image.asset(
                                      'assets/logo.png',
                                      width: 18,
                                      height: 18,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const SizedBox(),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CHAPTER ${index + 1}',
                                    style: GoogleFonts.cinzel(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF92400E),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const Text(' ⚜️', style: TextStyle(fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: Text(
                                  _chapterTitles[index],
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: Container(
                                  width: 60,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Dynamic Chapter Page Content with safe independent scrolling
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  child: _buildChapterContent(index),
                                ),
                              ),

                              // Page Footer
                              const SizedBox(height: 8),
                              const Divider(color: Color(0xFFE2D6C5), height: 1),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'OneFellowship • Benevolent Constitution',
                                    style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '— Page ${index + 1} of $_totalPages —',
                                    style: GoogleFonts.cinzel(fontSize: 11, color: const Color(0xFF92400E), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Rock-Solid Navigation Footer with zero text clipping and home redirection
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              // PREVIOUS BUTTON
              Expanded(
                child: _buildNavButton(
                  onTap: _goToPrevPage,
                  icon: _currentPage > 0 ? Icons.arrow_back_rounded : Icons.book_rounded,
                  label: _currentPage > 0 ? 'Prev Page' : 'Cover Page',
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  border: BorderSide(
                    color: _currentPage > 0 ? const Color(0xFFD4AF37) : Colors.white24,
                    width: 1.5,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // NEXT BUTTON OR DONE / RATIFY BUTTON
              Expanded(
                child: _currentPage < _totalPages - 1
                    ? _buildNavButton(
                        onTap: _goToNextPage,
                        icon: Icons.arrow_forward_rounded,
                        label: 'Next Page',
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF0F172A),
                      )
                    : (_hasAgreed
                        ? _buildNavButton(
                            onTap: _returnToHome,
                            icon: Icons.home_rounded,
                            label: 'Done • Home',
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          )
                        : _buildNavButton(
                            onTap: _performRatification,
                            icon: Icons.verified_rounded,
                            label: 'Ratify & Agree',
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: const Color(0xFF0F172A),
                          )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    BorderSide? border,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: border != null ? Border.fromBorderSide(border) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foregroundColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CHAPTER CONTENT PAGES
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildChapterContent(int index) {
    switch (index) {
      case 0:
        return _buildPreamblePage();
      case 1:
        return _buildRegistrationPage();
      case 2:
        return _buildCommitmentFeePage();
      case 3:
        return _buildMinimumContributionPage();
      case 4:
        return _buildMembersCoveredPage();
      case 5:
        return _buildOccasionsCoveredPage();
      case 6:
        return _buildAuthorizationPage();
      case 7:
        return _buildDisciplinePage();
      case 8:
        return _buildRatificationPage();
      default:
        return const SizedBox();
    }
  }

  // Page 1: Preamble & Scripture
  Widget _buildPreamblePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prestigious Branded Header
        Center(
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: ClipOval(
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ONEFELLOWSHIP BENEVOLENT FUND',
                style: GoogleFonts.cinzel(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF78350F),
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'United in Fellowship • Driven by Care',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Column(
            children: [
              const Icon(Icons.format_quote_rounded, color: Color(0xFFB45309), size: 30),
              const SizedBox(height: 6),
              Text(
                '“Let all things be done decently and in order.”',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF78350F),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '— 1st Corinthians 14:40 (Amen)',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Five Core Welfare Principles',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),
        _buildParchmentBullet(Icons.visibility_rounded, 'Transparency and Accountability', 'Open financial records, auditable disbursements, and regular member accounting.'),
        _buildParchmentBullet(Icons.diversity_3_rounded, 'Unity and Mutual Support', 'Standing together in solidarity during seasons of grief, joy, and acute member hardship.'),
        _buildParchmentBullet(Icons.verified_user_rounded, 'Integrity and Responsible Leadership', 'Fiduciary stewardship without personal bias or conflict of interest.'),
        _buildParchmentBullet(Icons.handshake_rounded, 'Respect for Members and Officials', 'Mutual dignity across leadership and general membership at all times.'),
        _buildParchmentBullet(Icons.how_to_vote_rounded, 'Collective Decision Making', 'Constitutional amendments and critical resolutions enacted by member consensus.'),
      ],
    );
  }

  // Page 2: Membership Registration
  Widget _buildRegistrationPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArticleBadge('Article 1', 'Membership Requirements'),
        const SizedBox(height: 12),
        _buildParchmentText('Every registered member shall fulfill the following mandatory KYC requirements:'),
        const SizedBox(height: 10),
        _buildParchmentItem('i.', 'Full legal names and primary contact details (mobile phone and email).'),
        _buildParchmentItem('ii.', 'Name, contact details, relationship, and verified identification of designated Next of Kin.'),
        _buildParchmentItem('iii.', 'A verified copy of National ID card, Passport, or recognized identification document.'),
        _buildParchmentItem('iv.', 'Administrative and origin location: County, Sub-County, Ward, and Village / Estate.'),
        _buildParchmentItem('v.', 'Any other document deemed necessary by the Welfare Committee to verify eligibility.'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Membership shall become active upon full completion of registration requirements and payment of the commitment fee.',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Page 3: Commitment Fee
  Widget _buildCommitmentFeePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArticleBadge('Article 2', 'Commitment Fee Policy'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          ),
          child: Column(
            children: [
              Text('One-Time Commitment Fee', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text('KES 1,000', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                child: Text('STRICTLY NON-REFUNDABLE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildParchmentBullet(Icons.lock_clock_rounded, 'Upfront Payment', 'Commitment contributions shall be paid upfront within stipulated timelines to activate membership benefits.'),
        _buildParchmentBullet(Icons.balance_rounded, 'Equal Application', 'The commitment contribution amount shall apply equally to all eligible welfare members unless amended by general consensus.'),
      ],
    );
  }

  // Page 4: Minimum Proposed Contribution
  Widget _buildMinimumContributionPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArticleBadge('Article 3', 'Minimum Proposed Contribution'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          ),
          child: Column(
            children: [
              Text('Minimum Contribution Threshold', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text('KES 1,000', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF047857))),
              const SizedBox(height: 4),
              Text('Per member per eligible welfare case', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF065F46))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildParchmentText('All active members mutually agree to contribute at least KES 1,000 towards each approved benevolent occasion.'),
        const SizedBox(height: 10),
        _buildParchmentBullet(Icons.favorite_rounded, 'Solidarity Fund', 'Contributions are pooled transparently to ensure immediate family relief and dignified support.'),
      ],
    );
  }

  // Page 5: Members Covered
  Widget _buildMembersCoveredPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArticleBadge('Article 4', 'Members Covered Under Fund'),
        const SizedBox(height: 12),
        _buildParchmentText('The benevolent welfare fund strictly covers the following nuclear family entities:'),
        const SizedBox(height: 12),
        _buildParchmentBullet(Icons.person, 'The Registered Member', 'The primary account holder in active standing.'),
        _buildParchmentBullet(Icons.favorite, 'Legally Recognized Spouse', 'Declared spouse verified via marriage certificate or declaration.'),
        _buildParchmentBullet(Icons.child_care, 'Biological or Adopted Children', 'Registered dependants with birth certificate or legal adoption papers.'),
        _buildParchmentBullet(Icons.elderly, 'Biological Parents', 'Mother and father of the registered member.'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Text(
            '⚠️ IMPORTANT KYC RULE: Only the person declared during registration or officially updated thereafter shall qualify for benefits.',
            style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF92400E), height: 1.3),
          ),
        ),
      ],
    );
  }

  // Page 6: Covered Occasions & Timelines
  Widget _buildOccasionsCoveredPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArticleBadge('Article 5', 'Covered Occasions & Timelines'),
        const SizedBox(height: 12),
        _buildParchmentBullet(
          Icons.sentiment_very_dissatisfied_rounded,
          'Bereavement & Funeral Support',
          'Notice must be formally communicated at least 3 days before the burial date.',
        ),
        const SizedBox(height: 8),
        _buildParchmentBullet(
          Icons.celebration_rounded,
          'Weddings & Approved Celebrations',
          'Formal notice and invitation submitted at least 2 weeks before the wedding date.',
        ),
        const SizedBox(height: 8),
        _buildParchmentBullet(
          Icons.emergency_rounded,
          'Other Critical Emergencies',
          'Hospitalization, acute distress, or emergencies as formally approved by members.',
        ),
      ],
    );
  }

  // Page 7: Transaction Authorization
  Widget _buildAuthorizationPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArticleBadge('Article 6', 'Authorization of Transactions'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mandatory Triple Authorization Rule', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5, color: const Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text(
                'All withdrawals, payments, and disbursements from the welfare account must be authorized jointly by:',
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              _buildAuthorityChip('1. Office of the Chairperson'),
              _buildAuthorityChip('2. Office of the Secretary'),
              _buildAuthorityChip('3. Office of the Treasurer'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildParchmentBullet(
          Icons.gavel_rounded,
          'Strict Solo Prohibition',
          'No single official shall independently authorize withdrawal or disbursement of welfare funds under any circumstance.',
        ),
        _buildParchmentBullet(
          Icons.receipt_long_rounded,
          'Documentation & Receipts',
          'All financial transactions must be properly documented, backed by verified receipts and bank/M-Pesa statements.',
        ),
      ],
    );
  }

  Widget _buildAuthorityChip(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF0284C7), size: 16),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12.5, color: const Color(0xFF0369A1))),
        ],
      ),
    );
  }

  // Page 8: Disciplinary Measures & Fraud Safeguards
  Widget _buildDisciplinePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArticleBadge('Article 7', 'Discipline & Anti-Fraud Safeguards'),
        const SizedBox(height: 12),
        _buildParchmentBullet(
          Icons.warning_amber_rounded,
          'Two-Case Default Rule',
          'A member who fails to submit contributions for two consecutive welfare cases shall be liable to termination of membership.',
        ),
        _buildParchmentBullet(
          Icons.timer_rounded,
          '7-Day Grace Period',
          'Any late submission will be given a grace period of 7 calendar days before penalties apply.',
        ),
        _buildParchmentBullet(
          Icons.contact_phone_rounded,
          'Next of Kin Notification',
          'The member’s registered Next of Kin shall be officially notified when termination proceedings arise.',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF4444)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Misappropriation & Embezzlement Policy', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF991B1B))),
              const SizedBox(height: 4),
              Text(
                'In case of any embezzlement of funds, the Treasurer or implicated official shall immediately be restricted from accessing welfare accounts. An independent church audit team shall investigate, and legal action will be taken under applicable Kenyan laws.',
                style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF7F1D1D), height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Page 9: Ratification & Affirmation
  Widget _buildRatificationPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArticleBadge('Article 8', 'Ratification & Digital Affirmation'),
        const SizedBox(height: 14),

        // Official Digital Wax Seal with Logo
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFD4AF37),
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'OFFICIAL SEAL OF RATIFICATION',
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E),
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Enacted by OneFellowship Benevolent Fund',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF78350F),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildParchmentText('Ratified by the Executive Governance and Church Fellowship:'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  children: [
                    const Icon(Icons.history_edu_rounded, color: Color(0xFFD4AF37), size: 24),
                    const SizedBox(height: 4),
                    Text('Chairperson', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Executive Office', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  children: [
                    const Icon(Icons.draw_rounded, color: Color(0xFFD4AF37), size: 24),
                    const SizedBox(height: 4),
                    Text('Secretary', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Records & Notice', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD4AF37), size: 24),
                    const SizedBox(height: 4),
                    Text('Treasurer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Treasury Office', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (_hasAgreed) ...[
          // PERMANENTLY LOCKED & MARKED RATIFICATION CERTIFICATE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF059669), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.15),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RATIFIED & PERMANENTLY LOCKED',
                            style: GoogleFonts.cinzel(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF065F46),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Legally Binding Covenant Signed',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 28),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFA7F3D0), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Signed & ratified on ${_agreedAtDate != null && _agreedAtDate!.length >= 10 ? _agreedAtDate!.substring(0, 10) : DateTime.now().toIso8601String().substring(0, 10)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your ratification is permanently locked and recorded in fellowship archives. You may freely browse and review all chapters of the constitution at any time.',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF065F46),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                // Prominent Return to Home button right on certificate
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                    onPressed: _returnToHome,
                    icon: const Icon(Icons.home_rounded, size: 20),
                    label: Text(
                      'Done • Return to Home Page',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // UNAGREED - RATIFICATION ACTION CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: Color(0xFFB45309), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Digital Affirmation & Agreement',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'By ratifying below, you solemnly pledge to abide by all the rules, constitution, KES 1,000 commitment fee, KES 1,000 minimum contributions, 7-day grace period, and disciplinary guidelines of OneFellowship under 1st Corinthians 14:40.',
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: const Color(0xFF0B192C),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                    onPressed: _isSavingAgreement ? null : _performRatification,
                    icon: _isSavingAgreement
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B192C)),
                          )
                        : const Icon(Icons.verified_rounded, size: 20),
                    label: Text(
                      _isSavingAgreement ? 'Recording Ratification...' : 'Solemnly Ratify & Agree',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // VIEW 3: CONTINUOUS SCROLL VIEW (FOR READERS WHO PREFER SCROLLING)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildContinuousScrollView() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branded Continuous Scroll Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F254B), Color(0xFF0B172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.contain)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ONEFELLOWSHIP CONSTITUTION',
                        style: GoogleFonts.cinzel(color: const Color(0xFFFFFBEB), fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Continuous Reading View • All 9 Chapters',
                        style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (_hasAgreed)
                  const Icon(Icons.verified_rounded, color: AppColors.success, size: 24),
              ],
            ),
          ),
          ...List.generate(_totalPages, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2D6C5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(8)),
                        child: Text('CHAPTER ${i + 1}', style: GoogleFonts.cinzel(color: const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _chapterTitles[i],
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildChapterContent(i),
                ],
              ),
            );
          }),

          if (_hasAgreed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _returnToHome,
                icon: const Icon(Icons.home_rounded, size: 22),
                label: Text(
                  'Done Reading • Return to Home Page',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildArticleBadge(String badge, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD4AF37)),
          ),
          child: Text(
            badge.toUpperCase(),
            style: GoogleFonts.outfit(color: const Color(0xFF78350F), fontWeight: FontWeight.w800, fontSize: 10.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildParchmentText(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF334155), height: 1.45),
    );
  }

  Widget _buildParchmentItem(String prefix, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(prefix, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF92400E))),
          ),
          Expanded(
            child: Text(body, style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF334155), height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildParchmentBullet(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF92400E), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(desc, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
