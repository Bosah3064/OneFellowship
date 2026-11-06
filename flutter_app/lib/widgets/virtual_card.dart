import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VirtualCard extends StatelessWidget {
  final String memberName;
  final String memberNumber;
  final String memberSince;
  final double totalPaid;
  final double outstanding;
  final bool balancesVisible;
  final VoidCallback onToggleBalances;
  final int themeIndex;

  const VirtualCard({
    super.key,
    required this.memberName,
    required this.memberNumber,
    required this.memberSince,
    required this.totalPaid,
    required this.outstanding,
    required this.balancesVisible,
    required this.onToggleBalances,
    this.themeIndex = 0,
  });

  /// The 4 gradient themes for the card background.
  static const List<List<Color>> _themes = [
    // Theme 0 – Default Glamour: Navy → Purple → Crimson
    [Color(0xFF1d5f99), Color(0xFF683669), Color(0xFFa5243d)],
    // Theme 1 – Ocean Teal: Cyan → Blue → Indigo
    [Color(0xFF0891b2), Color(0xFF1e40af), Color(0xFF3730a3)],
    // Theme 2 – Sunset Orange: Rose → Orange → Yellow
    [Color(0xFFe11d48), Color(0xFFf97316), Color(0xFFeab308)],
    // Theme 3 – Emerald Green: Emerald → Teal → Cyan
    [Color(0xFF059669), Color(0xFF0d9488), Color(0xFF06b6d4)],
  ];

  List<Color> get _colors => _themes[themeIndex.clamp(0, _themes.length - 1)];

  String get _formattedNumber {
    final cleaned = memberNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final last8 = cleaned.length >= 8
        ? cleaned.substring(cleaned.length - 8)
        : cleaned.padLeft(8, '0');
    return '\u2022\u2022\u2022\u2022  \u2022\u2022\u2022\u2022  ${last8.substring(0, 4)}  ${last8.substring(4)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;

    return AspectRatio(
      aspectRatio: 85.6 / 54,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: colors[1].withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Holographic shimmer overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                      Colors.white.withOpacity(0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Card content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOP ROW: Chip + NFC + Logo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // EMV Chip
                      _buildChip(),
                      const SizedBox(width: 10),
                      // NFC Icon
                      Icon(
                        Icons.contactless_rounded,
                        color: Colors.white.withOpacity(0.7),
                        size: 24,
                      ),
                      const Spacer(),
                      // Brand
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'MEMBERSHIP',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'GLAMOROUS CARE',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // CARD NUMBER
                  Text(
                    _formattedNumber,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // BOTTOM: Name + Valid Thru + Member Since
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARD HOLDER',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              memberName.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'VALID THRU',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '12/29',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          Text(
                            'MEMBER SINCE',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            memberSince,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // BALANCE BAR
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'TOTAL PAID',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: onToggleBalances,
                                    child: Icon(
                                      balancesVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: Colors.white.withOpacity(0.6),
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                balancesVisible
                                    ? 'KES ${totalPaid.toStringAsFixed(0)}'
                                    : 'KES ****',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'OUTSTANDING',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              balancesVisible
                                  ? 'KES ${outstanding.toStringAsFixed(0)}'
                                  : 'KES ****',
                              style: GoogleFonts.inter(
                                color: balancesVisible
                                    ? (outstanding > 0
                                        ? const Color(0xFFFFCBC8)
                                        : const Color(0xFFC8FFC8))
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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

  Widget _buildChip() {
    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          colors: [Color(0xFFc9a84c), Color(0xFFdaa520), Color(0xFFc9a84c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Horizontal lines
          Positioned(
            top: 7,
            left: 0,
            right: 0,
            child: Container(height: 0.5, color: const Color(0xFFb8941f)),
          ),
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Container(height: 0.5, color: const Color(0xFFb8941f)),
          ),
          Positioned(
            top: 21,
            left: 0,
            right: 0,
            child: Container(height: 0.5, color: const Color(0xFFb8941f)),
          ),
          // Vertical line
          Positioned(
            top: 0,
            bottom: 0,
            left: 19,
            child: Container(width: 0.5, color: const Color(0xFFb8941f)),
          ),
        ],
      ),
    );
  }
}
