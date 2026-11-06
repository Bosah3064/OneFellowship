import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../services/supabase_service.dart';
import '../services/offline_cache_service.dart';
import '../widgets/virtual_card.dart';
import '../widgets/summary_card.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'payment_history_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';

bool _hasPlayedGreeting = false;

class DashboardScreen extends StatefulWidget {
  static const route = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _balancesVisible = false;
  Map<String, dynamic>? _member;
  List<Map<String, dynamic>> _payments = [];
  late ConfettiController _confettiController;
  final ScreenshotController _screenshotController = ScreenshotController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _unreadNotifications = 0;
  bool _hasCheckedProfile = false;
  bool _isOffline = false;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadData();
    _playCelebration();
  }

  void _playCelebration() async {
    // We try to play a sound. If it fails (e.g. no asset), we just vibrate.
    try {
      HapticFeedback.heavyImpact();
      _confettiController.play();
      await _audioPlayer.play(AssetSource('sounds/success.wav'));
    } catch (_) {}

    // Check if TTS is enabled and hasn't been played yet
    if (!_hasPlayedGreeting) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isTtsEnabled = prefs.getBool('voice_greeting') ?? true;
        
        if (isTtsEnabled) {
          // Small delay so greeting doesn't overlap with celebration sound
          await Future.delayed(const Duration(milliseconds: 1500));
          
          final tts = FlutterTts();
          await tts.setLanguage("en-US");
          await tts.setSpeechRate(0.4);   // Slower, more deliberate
          await tts.setPitch(0.95);        // Slightly deeper, professional
          await tts.setVolume(0.85);       // Soft, not loud
          
          // Try to pick a smooth American voice
          final voices = await tts.getVoices;
          if (voices is List) {
            final americanVoice = voices.firstWhere(
              (v) => v is Map && 
                     (v['locale']?.toString().startsWith('en-US') ?? false),
              orElse: () => null,
            );
            if (americanVoice != null && americanVoice is Map) {
              await tts.setVoice({"name": americanVoice['name'].toString(), "locale": "en-US"});
            }
          }
          
          final user = SupabaseService.currentUser;
          if (user != null) {
            String name = (user.userMetadata?['full_name'] ?? 'Member').toString().split(' ').first;
            await tts.speak("Welcome back, $name. To the Glamorous Care Initiative.");
          }
        }
        _hasPlayedGreeting = true;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    _notificationSub?.cancel();
    super.dispose();
  }

  bool _isStreamInitialized = false;
  final Set<String> _seenNotificationIds = {};

  void _setupNotificationStream(String memberId) {
    _notificationSub?.cancel();
    _notificationSub = SupabaseService.notificationsStream(memberId).listen((notifs) {
      if (!mounted) return;
      
      final unreadNotifs = notifs.where((n) => n['is_read'] == false).toList();
      final newUnreadCount = unreadNotifs.length;
      
      if (_isStreamInitialized) {
        // Find if there is any brand new unread notification we haven't seen yet
        final brandNew = unreadNotifs.where((n) => !_seenNotificationIds.contains(n['id'].toString())).toList();
        if (brandNew.isNotEmpty) {
          _showLiveNotificationPopup(brandNew.first);
        }
      }
      
      // Track all current unread notification IDs so we don't trigger them again
      for (final n in unreadNotifs) {
        _seenNotificationIds.add(n['id'].toString());
      }
      
      _isStreamInitialized = true;
      
      setState(() {
        _unreadNotifications = newUnreadCount;
      });
    });
  }

  void _showLiveNotificationPopup(Map<String, dynamic> notif) {
    // Play sound and vibrate
    HapticFeedback.mediumImpact();
    _audioPlayer.play(AssetSource('sounds/success.wav'));
    
    final title = notif['title']?.toString() ?? 'New Notification';
    final message = notif['message']?.toString() ?? '';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(message, style: GoogleFonts.outfit(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 10, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection.up,
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final member = await SupabaseService.fetchCurrentMember();
      List<Map<String, dynamic>> payments = [];
      int unreadCount = 0;
      if (member != null) {
        payments = await SupabaseService.fetchMemberPayments(member['id']);
        unreadCount = await SupabaseService.countUnreadNotifications(member['id']);
        // Cache for offline use
        await OfflineCacheService.cacheMember(member);
        await OfflineCacheService.cachePayments(payments);
      }
      if (mounted) {
        setState(() {
          _member = member;
          _payments = payments;
          _unreadNotifications = unreadCount;
          _isLoading = false;
          _isOffline = false;
        });
        
        if (member != null) {
          _setupNotificationStream(member['id']);
        }
        
        if (!_hasCheckedProfile) {
          _hasCheckedProfile = true;
          _checkProfileCompletion();
        }
      }
    } catch (e) {
      // Offline fallback: load from cache
      try {
        final cachedMember = await OfflineCacheService.getCachedMember();
        final cachedPayments = await OfflineCacheService.getCachedPayments();
        if (mounted) {
          setState(() {
            _member = cachedMember;
            _payments = cachedPayments;
            _isLoading = false;
            _isOffline = true;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // === Profile schema matching the website's canonicalFields ===
  // Each required field: { key, label, isFieldOnMember (phone lives on members table) }
  static const _profileFields = [
    {'key': 'phone', 'label': 'Phone Number', 'isFieldOnMember': true},
    {'key': 'date_of_birth', 'label': 'Date of Birth', 'isFieldOnMember': false},
    {'key': 'gender', 'label': 'Gender', 'isFieldOnMember': false},
    {'key': 'marital_status', 'label': 'Marital Status', 'isFieldOnMember': false},
    {'key': 'id_number', 'label': 'National ID Number', 'isFieldOnMember': false},
    {'key': 'branch', 'label': 'Branch', 'isFieldOnMember': false},
    {'key': 'occupation', 'label': 'Occupation', 'isFieldOnMember': false},
    {'key': 'next_of_kin_name', 'label': 'Next of Kin Name', 'isFieldOnMember': false},
    {'key': 'next_of_kin_phone', 'label': 'Next of Kin Phone', 'isFieldOnMember': false},
    {'key': 'dependants', 'label': 'Any Dependants?', 'isFieldOnMember': false},
    {'key': 'dependant_count', 'label': 'Number of Dependants', 'isFieldOnMember': false},
  ];

  // Match website's variationsMap — check legacy field name variations
  static const _variationsMap = {
    'date_of_birth': ['date of birth', 'dob', 'date_of_birth'],
    'gender': ['gender'],
    'marital_status': ['marital status', 'marital_status'],
    'id_number': ['national id number', 'id number', 'national id', 'id_number', 'national_id_number'],
    'branch': ['branch'],
    'occupation': ['occupation', 'profession', 'occupation/profession'],
    'next_of_kin_name': ['next of kin full name', 'next of kin name', 'next_of_kin_name', 'next_of_kin_full_name'],
    'next_of_kin_phone': ['next of kin phone', 'next of kin_phone', 'next_of_kin_phone_number'],
    'dependants': ['dependants', 'dependents'],
    'dependant_count': ['dependant_count', 'number of dependants'],
  };

  /// Resolve a field value from form_details using canonical key + variations (matches website)
  String _resolveFieldValue(Map<String, dynamic> fd, String canonicalKey) {
    // Direct match first
    final direct = fd[canonicalKey];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return _formatValue(direct);
    }
    // Try variations
    final variations = _variationsMap[canonicalKey] ?? [];
    for (final fdKey in fd.keys) {
      final clean = fdKey.toLowerCase().trim();
      if (clean == canonicalKey || variations.any((v) => v.toLowerCase().trim() == clean)) {
        final val = fd[fdKey];
        if (val != null && val.toString().trim().isNotEmpty) {
          return _formatValue(val);
        }
      }
    }
    return '';
  }

  String _formatValue(dynamic val) {
    if (val is List) {
      if (val.isEmpty) return '';
      if (val.first is Map) {
        return val.map((r) => '${r['full_name'] ?? ''} (${r['relationship'] ?? ''})').join(', ');
      }
      return val.join(', ');
    }
    return val.toString().trim();
  }

  void _checkProfileCompletion() {
    if (_member == null) return;

    final fd = _member!['form_details'] as Map<String, dynamic>? ?? {};
    
    // Build list of missing fields (matching website logic exactly)
    final missingFields = <Map<String, dynamic>>[];
    for (final field in _profileFields) {
      final key = field['key'] as String;
      final isOnMember = field['isFieldOnMember'] as bool;
      
      String value;
      if (isOnMember) {
        value = _member![key]?.toString().trim() ?? '';
      } else {
        value = _resolveFieldValue(fd, key);
      }
      
      if (value.isEmpty) {
        missingFields.add(field);
      }
    }

    if (missingFields.isNotEmpty) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _showProfileCompletionDialog(missingFields);
        }
      });
    }
  }

  void _showProfileCompletionDialog(List<Map<String, dynamic>> missingFields) {
    // Create controllers for ONLY the missing fields
    final controllers = <String, TextEditingController>{};
    final genderOptions = ['Male', 'Female'];
    final maritalOptions = ['Married', 'Single', 'Divorced', 'Widowed'];
    final dependantsOptions = ['Yes', 'No'];
    String? selectedGender;
    String? selectedMarital;
    String? selectedDependants;

    for (final field in missingFields) {
      controllers[field['key'] as String] = TextEditingController();
    }

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, color: AppColors.warning, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Complete Your Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17))),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(color: const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'You have ${missingFields.length} missing field${missingFields.length > 1 ? 's' : ''}. Please fill in below.',
                        style: GoogleFonts.outfit(color: const Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...missingFields.map((field) {
                      final key = field['key'] as String;
                      final label = field['label'] as String;

                      // Gender dropdown
                      if (key == 'gender') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            value: selectedGender,
                            decoration: InputDecoration(
                              labelText: label,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            items: genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) => setStateDialog(() => selectedGender = val),
                          ),
                        );
                      }

                      // Marital status dropdown
                      if (key == 'marital_status') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            value: selectedMarital,
                            decoration: InputDecoration(
                              labelText: label,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            items: maritalOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setStateDialog(() => selectedMarital = val),
                          ),
                        );
                      }

                      // Dependants dropdown
                      if (key == 'dependants') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            value: selectedDependants,
                            decoration: InputDecoration(
                              labelText: label,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            items: dependantsOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setStateDialog(() => selectedDependants = val),
                          ),
                        );
                      }

                      // Date of birth
                      if (key == 'date_of_birth') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: controllers[key],
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: label,
                              hintText: 'Tap to select',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixIcon: const Icon(Icons.calendar_today, size: 18),
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime(1990),
                                firstDate: DateTime(1940),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                controllers[key]!.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                              }
                            },
                          ),
                        );
                      }

                      // Phone field
                      if (key == 'phone') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: controllers[key],
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: label,
                              hintText: '07XX...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        );
                      }

                      // ID number fields
                      if (key.contains('id_number') || key.contains('national_id')) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: controllers[key],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: label,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        );
                      }

                      // Default text field
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: controllers[key],
                          decoration: InputDecoration(
                            labelText: label,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Later', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                ),
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  )
                else
                  ElevatedButton(
                    onPressed: () async {
                      setStateDialog(() => isSaving = true);
                      try {
                        final fd = Map<String, dynamic>.from(_member!['form_details'] as Map<String, dynamic>? ?? {});
                        String? phone;

                        for (final field in missingFields) {
                          final key = field['key'] as String;
                          String value = '';

                          if (key == 'gender') {
                            value = selectedGender ?? '';
                          } else if (key == 'marital_status') {
                            value = selectedMarital ?? '';
                          } else if (key == 'dependants') {
                            value = selectedDependants ?? '';
                          } else {
                            value = controllers[key]?.text.trim() ?? '';
                          }

                          if (key == 'phone') {
                            phone = value;
                          } else {
                            fd[key] = value;
                          }
                        }

                        final updateData = <String, dynamic>{'form_details': fd};
                        if (phone != null && phone.isNotEmpty) {
                          updateData['phone'] = phone;
                        }

                        await SupabaseService.updateMember(_member!['id'], updateData);
                        if (mounted) {
                          Navigator.pop(context);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Profile updated!', style: GoogleFonts.outfit()),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          setStateDialog(() => isSaving = false);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Save Details', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _downloadAsImage() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File('${directory.path}/virtual_card.png').create();
        await imagePath.writeAsBytes(image);
        await Share.shareXFiles([XFile(imagePath.path)], text: 'My Glamorous Care Virtual Card');
      }
    } catch (e) {
      debugPrint('Error sharing card image: $e');
    }
  }

  Future<void> _downloadAsPdf() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final pdf = pw.Document();
        final pdfImage = pw.MemoryImage(image);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(pdfImage),
              );
            },
          ),
        );
        
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/virtual_card.pdf');
        await file.writeAsBytes(await pdf.save());
        await Share.shareXFiles([XFile(file.path)], text: 'My Glamorous Care Virtual Card (PDF)');
      }
    } catch (e) {
      debugPrint('Error sharing card pdf: $e');
    }
  }

  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Download Card',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.image, color: AppColors.primary),
                  title: Text('Download as Image (PNG)', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadAsImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: AppColors.red),
                  title: Text('Download as Document (PDF)', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadAsPdf();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double get _totalPaid {
    return _payments
        .where((p) {
          final type = (p['payment_type'] ?? p['type'] ?? p['month'] ?? '').toString().toLowerCase();
          return !type.contains('registration') && !type.contains('reg');
        })
        .where((p) => (p['status'] ?? '').toString().toLowerCase() == 'paid')
        .fold(0.0, (sum, p) => sum + (num.tryParse(p['amount']?.toString() ?? '0')?.toDouble() ?? 0));
  }

  double get _totalPending {
    return _payments
        .where((p) => (p['status'] ?? '').toString().toLowerCase() != 'paid')
        .fold(0.0, (sum, p) => sum + (num.tryParse(p['amount']?.toString() ?? '0')?.toDouble() ?? 0));
  }

  // Registration fee is NOT withdrawable — separate from savings
  double get _registrationFee {
    return _payments
        .where((p) {
          final type = (p['payment_type'] ?? p['type'] ?? p['month'] ?? '').toString().toLowerCase();
          return type.contains('registration') || type.contains('reg');
        })
        .where((p) => (p['status'] ?? '').toString().toLowerCase() == 'paid')
        .fold(0.0, (sum, p) => sum + (num.tryParse(p['amount']?.toString() ?? '0')?.toDouble() ?? 0));
  }

  // Total Savings = only monthly contributions (paid), excluding registration AND paid out funds
  double get _totalSavings {
    return _payments
        .where((p) {
          final type = (p['payment_type'] ?? p['type'] ?? p['month'] ?? '').toString().toLowerCase();
          final payoutStatus = (p['payout_status'] ?? '').toString().toLowerCase();
          return !type.contains('registration') && !type.contains('reg') && payoutStatus != 'paid_out';
        })
        .where((p) => (p['status'] ?? '').toString().toLowerCase() == 'paid')
        .fold(0.0, (sum, p) => sum + (num.tryParse(p['amount']?.toString() ?? '0')?.toDouble() ?? 0));
  }

  String get _memberName => _member?['full_name'] ?? 'Member';
  String get _firstName => _memberName.split(' ').first;
  String get _memberNumber {
    if (_member == null) return '0000 0000 0000 0000';
    if (_member!['member_number'] != null && _member!['member_number'].toString().trim().isNotEmpty) {
      return _member!['member_number'].toString();
    }
    
    // Generate deterministic 16-digit account number from UUID
    final String uuid = _member!['id'].toString().replaceAll('-', '');
    String digits = '';
    for (int i = 0; i < uuid.length; i++) {
      digits += (uuid.codeUnitAt(i) % 10).toString();
      if (digits.length >= 16) break;
    }
    if (digits.length < 16) digits = digits.padRight(16, '0');
    return '${digits.substring(0,4)} ${digits.substring(4,8)} ${digits.substring(8,12)} ${digits.substring(12,16)}';
  }
  int get _cardTheme => (_member?['form_details'] as Map<String, dynamic>?)?['card_theme'] as int? ?? 0;
  
  String get _memberSince {
    final joinDate = _member?['join_date'];
    if (joinDate == null) return 'N/A';
    try {
      final dt = DateTime.parse(joinDate.toString());
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  String get _initials {
    final parts = _memberName.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _greetingEmoji {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  List<Map<String, dynamic>> get _recentPayments {
    final sorted = List<Map<String, dynamic>>.from(_payments);
    sorted.sort((a, b) {
      final da = DateTime.tryParse(a['payment_date']?.toString() ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['payment_date']?.toString() ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });
    return sorted.take(5).toList();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    switch (index) {
      case 1:
        Navigator.pushNamed(context, PaymentHistoryScreen.route).then((_) {
          setState(() => _currentIndex = 0);
          _loadData();
        });
        break;
      case 2:
        Navigator.pushNamed(context, SettingsScreen.route).then((_) {
          setState(() => _currentIndex = 0);
          _loadData();
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit App?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Text('Are you sure you want to exit the app?', style: GoogleFonts.outfit()),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Exit', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ?? false;
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      slivers: [
                        // --- Premium Header ---
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1d5f99), Color(0xFF2a4a7f), Color(0xFF683669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                          ),
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
                                          gradient: LinearGradient(
                                            colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _initials,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$_greeting $_greetingEmoji',
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withOpacity(0.7),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _firstName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(context, NotificationsScreen.route).then((_) => _loadData());
                                        },
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                              ),
                                              child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                                            ),
                                            if (_unreadNotifications > 0)
                                              Positioned(
                                                right: -4,
                                                top: -4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.red,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: const Color(0xFF1d5f99), width: 2),
                                                  ),
                                                  child: Text(
                                                    _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Quick stats strip inside header
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildHeaderStat('Savings', _balancesVisible ? 'KES ${_totalSavings.toStringAsFixed(0)}' : '****', Icons.savings_rounded),
                                        Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2)),
                                        _buildHeaderStat('Pending', _balancesVisible ? 'KES ${_totalPending.toStringAsFixed(0)}' : '****', Icons.schedule_rounded),
                                        Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2)),
                                        _buildHeaderStat('Payments', '${_payments.length}', Icons.receipt_long_rounded),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // --- Offline Mode Banner ---
                      if (_isOffline)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded, color: Color(0xFFB8860B), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Free Mode — You\'re viewing cached data. Connect to the internet to sync.',
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF856404)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // --- Virtual Card ---
                      SliverToBoxAdapter(
                        child: Padding(
                          // Increased horizontal padding from 20 to 32 to reduce card width slightly
                          padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
                          child: Column(
                            children: [
                              Screenshot(
                                controller: _screenshotController,
                                child: VirtualCard(
                                  memberName: _memberName,
                                  memberNumber: _memberNumber,
                                  memberSince: _memberSince,
                                  totalPaid: _totalPaid,
                                  outstanding: _totalPending,
                                  balancesVisible: _balancesVisible,
                                  themeIndex: _cardTheme,
                                  onToggleBalances: () {
                                    setState(() => _balancesVisible = !_balancesVisible);
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _showDownloadOptions,
                                icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 18),
                                label: Text(
                                  'Save / Share Card',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- Quick Actions ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Text(
                            'Quick Actions',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            children: [
                              _buildQuickAction(Icons.visibility_rounded, 'Toggle\nBalances', AppColors.primary, () {
                                setState(() => _balancesVisible = !_balancesVisible);
                              }),
                              const SizedBox(width: 12),
                              _buildQuickAction(Icons.receipt_long_rounded, 'Payment\nHistory', AppColors.success, () {
                                Navigator.pushNamed(context, PaymentHistoryScreen.route);
                              }),
                              const SizedBox(width: 12),
                              _buildQuickAction(Icons.download_rounded, 'Save\nCard', AppColors.purple, _showDownloadOptions),
                              const SizedBox(width: 12),
                              _buildQuickAction(Icons.settings_rounded, 'Settings', AppColors.warning, () {
                                Navigator.pushNamed(context, SettingsScreen.route);
                              }),
                              const SizedBox(width: 12),
                              _buildQuickAction(Icons.notifications_rounded, 'Alerts', AppColors.red, () {
                                Navigator.pushNamed(context, NotificationsScreen.route);
                              }),
                            ],
                          ),
                        ),
                      ),

                      // --- Financial Overview ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Text(
                            'Financial Overview',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildGradientStatCard(
                                  'Total Paid',
                                  _balancesVisible ? 'KES ${_totalPaid.toStringAsFixed(0)}' : '****',
                                  Icons.check_circle_rounded,
                                  [const Color(0xFF16A34A), const Color(0xFF22C55E)],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildGradientStatCard(
                                  'Pending',
                                  _balancesVisible ? 'KES ${_totalPending.toStringAsFixed(0)}' : '****',
                                  Icons.pending_actions_rounded,
                                  [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildGradientStatCard(
                                  'Savings',
                                  _balancesVisible ? 'KES ${_totalSavings.toStringAsFixed(0)}' : '****',
                                  Icons.savings_rounded,
                                  [const Color(0xFF1d5f99), const Color(0xFF3B82F6)],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildGradientStatCard(
                                  'Reg. Fee',
                                  _balancesVisible ? 'KES ${_registrationFee.toStringAsFixed(0)}' : '****',
                                  Icons.app_registration_rounded,
                                  [const Color(0xFF683669), const Color(0xFF9333EA)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // --- Invite Banner ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)], // Purple vibrant gradient
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Invite & Earn',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Invite a member and earn KES 100 reward!',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Share feature coming soon!', style: GoogleFonts.outfit()),
                                        backgroundColor: AppColors.primary,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF8B5CF6),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: Text('Share', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- Recent Payments ---
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Payments',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, PaymentHistoryScreen.route),
                                child: Text(
                                  'See All',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_recentPayments.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF3F4F6)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No payments yet',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your payment history will appear here',
                                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final p = _recentPayments[index];
                              final status = (p['status'] ?? 'pending').toString().toLowerCase();
                              final amount = num.tryParse(p['amount']?.toString() ?? '0')?.toDouble() ?? 0;
                              final month = p['month'] ?? '-';
                              final date = p['payment_date'] ?? '';
                              final type = p['payment_type'] ?? p['type'] ?? 'Payment';

                              Color statusColor;
                              IconData statusIcon;
                              if (status == 'paid') {
                                statusColor = AppColors.success;
                                statusIcon = Icons.check_circle_rounded;
                              } else if (status == 'late') {
                                statusColor = AppColors.error;
                                statusIcon = Icons.warning_rounded;
                              } else {
                                statusColor = AppColors.warning;
                                statusIcon = Icons.schedule_rounded;
                              }

                              String formattedDate = '-';
                              try {
                                final dt = DateTime.parse(date.toString());
                                formattedDate = '${dt.day}/${dt.month}/${dt.year}';
                              } catch (_) {}

                              return Padding(
                                padding: EdgeInsets.fromLTRB(20, 0, 20, index == _recentPayments.length - 1 ? 100 : 10),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFFF3F4F6)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(statusIcon, color: statusColor, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              month.toString(),
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '$type \u2022 $formattedDate',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'KES ${amount.toStringAsFixed(0)}',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: statusColor,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _recentPayments.length,
                          ),
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.center, // Explode from center looks cooler
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    emissionFrequency: 0.05,
                    numberOfParticles: 50,
                    gravity: 0.2,
                    colors: const [
                      AppColors.primary,
                      AppColors.purple,
                      AppColors.red,
                      Colors.amber,
                      Colors.green,
                      Colors.blue,
                      Colors.pink,
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, 'Home', 0),
                _buildNavItem(Icons.receipt_long_rounded, 'Payments', 1),
                _buildNavItem(Icons.settings_rounded, 'Settings', 2),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.6), size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientStatCard(String title, String amount, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[0].withOpacity(0.08), colors[1].withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors[0].withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
