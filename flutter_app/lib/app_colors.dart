import 'package:flutter/material.dart';

class AppColors {
  // Brand colors (OneFellowship: Royal Blue, Deep Navy, Accent Gold, Vibrant Sky Blue)
  static const primary = Color(0xFF0B4FBB);
  static const primaryDark = Color(0xFF0A2D6B);
  static const secondary = Color(0xFFFFC107);
  static const gold = Color(0xFFFFC107);
  static const skyBlue = Color(0xFF29B6F6);
  static const royalBlue = Color(0xFF0B4FBB);
  
  // Background & Surfaces
  static const background = Color(0xFFF6F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFFFFFFF);
  
  // Text
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  
  // Status
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const danger = Color(0xFFEF4444);
  static const red = Color(0xFFEF4444);
  // Replaced legacy purple with royal blue / accent blue
  static const purple = Color(0xFF0B4FBB);
  
  // Gradients
  static const brandGradient = LinearGradient(
    colors: [primaryDark, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [primaryDark, primary, skyBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [primaryDark, Color(0xFF0C4A9E), Color(0xFF1A73E8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
