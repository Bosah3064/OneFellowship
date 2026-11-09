import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/biometric_unlock_screen.dart';
import 'screens/payment_history_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/manage_members_screen.dart';
import 'screens/manage_payments_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/manage_notifications_screen.dart';
import 'screens/admin_wallet_screen.dart';
import 'screens/admin_audit_logs_screen.dart';
import 'screens/terms_and_conditions_screen.dart';
import 'screens/force_change_password_screen.dart';
import 'services/biometric_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file in assets
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (e) {
    debugPrint('dotenv load error: $e');
  }

  String initRoute = WelcomeScreen.route;
  try {
    await SupabaseService.init();
    final valid = await SupabaseService.isSessionValid();
    if (valid) {
      final bioAvail = await BiometricService.isBiometricAvailable();
      final bioEnabled = await BiometricService.isBiometricEnabled();

      if (bioAvail && bioEnabled) {
        initRoute = BiometricUnlockScreen.route;
      } else {
        final u = SupabaseService.currentUser;
        if (u != null) {
          final profileDone = await SupabaseService.isProfileComplete(u.id);
          if (!profileDone) {
            initRoute = CompleteProfileScreen.route;
          } else {
            initRoute = DashboardScreen.route;
          }
        } else {
          initRoute = DashboardScreen.route;
        }
      }
    }
  } catch (e) {
    debugPrint('Firebase backend init error: $e');
  }
  runApp(OneFellowshipApp(initialRoute: initRoute));
}

class OneFellowshipApp extends StatelessWidget {
  final String initialRoute;
  const OneFellowshipApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneFellowship',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.danger,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: const Color(0xFF111827),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(
            color: const Color(0xFF111827),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Color(0xFF9CA3AF),
          type: BottomNavigationBarType.fixed,
          elevation: 20,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            textStyle: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            textStyle: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        WelcomeScreen.route: (_) => const WelcomeScreen(),
        LoginScreen.route: (_) => const LoginScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        CompleteProfileScreen.route: (_) => const CompleteProfileScreen(),
        BiometricUnlockScreen.route: (_) => const BiometricUnlockScreen(),
        ResetPasswordScreen.route: (_) => const ResetPasswordScreen(),
        ForceChangePasswordScreen.route: (_) => const ForceChangePasswordScreen(),
        DashboardScreen.route: (_) => const DashboardScreen(),
        PaymentHistoryScreen.route: (_) => const PaymentHistoryScreen(),
        AdminPanelScreen.route: (_) => const AdminPanelScreen(),
        ManageMembersScreen.route: (_) => const ManageMembersScreen(),
        ManagePaymentsScreen.route: (_) => const ManagePaymentsScreen(),
        ManageNotificationsScreen.route: (_) => const ManageNotificationsScreen(),
        AdminWalletScreen.route: (_) => const AdminWalletScreen(),
        AdminAuditLogsScreen.route: (_) => const AdminAuditLogsScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
        NotificationsScreen.route: (_) => const NotificationsScreen(),
        TermsAndConditionsScreen.route: (_) => const TermsAndConditionsScreen(),
      },
    );
  }
}
