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
  
  // Book navigation state
  bool _isBookOpen = false;
  bool _continuousScrollMode = false;
  int _currentPage = 0;
  final PageController _pageController = PageController();

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
                    setState(() {
                      _isBookOpen = true;
                      _continuousScrollMode = false;
                      _currentPage = i;
                    });
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(i);
                    }
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
            Text(
              _continuousScrollMode
                  ? 'Continuous Reading View'
                  : (_isBookOpen ? 'Page ${_currentPage + 1} of $_totalPages' : 'Official Sealed Volume'),
              style: GoogleFonts.outfit(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
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
        bottom: true,
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
                        // Embossed Crest Seal
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF142C57),
                            border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withOpacity(0.35),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.auto_stories_rounded, color: Color(0xFFD4AF37), size: 40),
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
                            _buildCoverBadge(Icons.menu_book, '9 Chapters'),
                            const SizedBox(width: 8),
                            _buildCoverBadge(Icons.calendar_month, 'Nov 2026'),
                            const SizedBox(width: 8),
                            _buildCoverBadge(Icons.verified, 'Ratified'),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // OPEN BOOK BUTTON (Full width, generous, never squeezed)
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: const Color(0xFF0B192C),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  // VIEW 2: THE PAGED BOOK SPREAD (SWIPEABLE PAGES)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPagedBookView() {
    return Column(
      children: [
        // Top Book Ribbon & Navigation Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0B172A),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() => _isBookOpen = false);
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFFD4AF37)),
                label: Text(
                  'Book Cover',
                  style: GoogleFonts.outfit(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                ),
                child: Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFDE68A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
                tooltip: 'Table of Contents',
                onPressed: _openTableOfContents,
              ),
            ],
          ),
        ),

        // The Page View
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _totalPages,
            onPageChanged: (idx) {
              setState(() => _currentPage = idx);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chapter Top Ornament
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('⚜️ ', style: TextStyle(fontSize: 14)),
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
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  _chapterTitles[index],
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
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
                              const SizedBox(height: 16),

                              // Dynamic Chapter Page Content
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: _buildChapterContent(index),
                                ),
                              ),

                              // Page Footer
                              const SizedBox(height: 10),
                              const Divider(color: Color(0xFFE2D6C5), height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'OneFellowship • Benevolent Constitution',
                                    style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '— Page ${index + 1} —',
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

        // Un-Squeezed Turn Page Navigation Footer
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              // PREVIOUS BUTTON
              if (_currentPage > 0)
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text('Prev Page', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => setState(() => _isBookOpen = false),
                      icon: const Icon(Icons.book_rounded, size: 18),
                      label: Text('Cover Page', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ),

              const SizedBox(width: 14),

              // NEXT BUTTON OR AFFIRM BUTTON
              if (_currentPage < _totalPages - 1)
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text('Next Page', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Action for final page
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please check the agreement box below to complete ratification.')),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text('Ratify & Agree', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
        const SizedBox(height: 12),
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

        // DIGITAL AFFIRMATION AGREEMENT CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hasAgreed ? const Color(0xFFECFDF5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hasAgreed ? AppColors.success : const Color(0xFFD4AF37), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: (_hasAgreed ? AppColors.success : const Color(0xFFD4AF37)).withOpacity(0.08),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _hasAgreed ? Icons.verified_rounded : Icons.gavel_rounded,
                    color: _hasAgreed ? AppColors.success : const Color(0xFFB45309),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Digital Affirmation & Agreement',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
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
                      onTap: () {
                        if (!_isSavingAgreement) _toggleAgreement(!_hasAgreed);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'I have read, understood, and solemnly agree to abide by all the rules, constitution, KES 1,000 commitment fee, KES 1,000 minimum contributions, 7-day grace period, and disciplinary guidelines of OneFellowship.',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_hasAgreed && _agreedAtDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  '✅ Bound & digitally ratified on ${_agreedAtDate!.length >= 10 ? _agreedAtDate!.substring(0, 10) : _agreedAtDate}',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
              ],
            ],
          ),
        ),
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
          _buildCoverBadge(Icons.auto_stories, 'Continuous Scroll Mode'),
          const SizedBox(height: 14),
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
