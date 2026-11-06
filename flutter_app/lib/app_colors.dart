import 'package:flutter/material.dart';

class AppColors {
  // Brand colors
  static const primary = Color(0xFF0B4FBB);
  static const primaryDark = Color(0xFF0A2D6B);
  static const secondary = Color(0xFFFFC107);
  static const skyBlue = Color(0xFF29B6F6);
  
  // Background
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  
  // Text
  static const textPrimary = Color(0xFF263238);
  static const textSecondary = Color(0xFF757575);
  static const textMuted = Color(0xFF9E9E9E);
  
  // Status
  static const success = Color(0xFF28A745);
  static const warning = Color(0xFFFB8C00);
  static const error = Color(0xFFE53935);
  static const danger = Color(0xFFE53935);
  static const red = Color(0xFFE53935);
  static const purple = Color(0xFF8E24AA);
  
  // Card gradient
  static const cardGradient = LinearGradient(
    colors: [primaryDark, primary, skyBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
