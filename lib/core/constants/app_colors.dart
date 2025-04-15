import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF5386DF); // Blue
  static const Color primaryLight = Color(0xFF749CE2); // Light blue
  static const Color primaryDark = Color(0xFF3A6BC0); // Dark blue
  
  // Secondary Colors
  static const Color secondary = Color(0xFF5BBFB2); // Soft teal
  static const Color secondaryLight = Color(0xFF89E5DA);
  static const Color secondaryDark = Color(0xFF389187);

  // Accent Colors
  static const Color accent = Color(0xFFFFA952); // Soft orange
  static const Color success = Color(0xFF5CD6A9); // Mint green
  static const Color error = Color(0xFFED6C79); // Soft red
  static const Color warning = Color(0xFFFFCC66); // Soft amber
  static const Color info = Color(0xFF90A0F8); // Soft purple

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF5386DF), // Blue
    Color(0xFF749CE2), // Light blue
  ];
  
  static const List<Color> successGradient = [
    Color(0xFF5CD6A9),
    Color(0xFF40C4A0),
  ];
  
  static const List<Color> errorGradient = [
    Color(0xFFED6C79),
    Color(0xFFE64057),
  ];
  
  // Neutrals - Light Mode
  static const Color background = Color(0xFFF9FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFAFCFF);
  static const Color surfaceMedium = Color(0xFFF0F4F8);
  static const Color surfaceDark = Color(0xFFE1E8ED);
  
  // Neutrals - Dark Mode
  static const Color backgroundDark = Color(0xFF121620);
  static const Color surfaceDark1 = Color(0xFF1E2433);
  static const Color surfaceDark2 = Color(0xFF262F42);
  static const Color surfaceDark3 = Color(0xFF323A4E);
  
  // Text Colors - Light Mode
  static const Color textPrimary = Color(0xFF2B3674);
  static const Color textSecondary = Color(0xFF6E7A9A);
  static const Color textTertiary = Color(0xFF8F9BB3);
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Text Colors - Dark Mode
  static const Color textPrimaryDark = Color(0xFFEDF2FC);
  static const Color textSecondaryDark = Color(0xFFB5BDCF);
  static const Color textTertiaryDark = Color(0xFF8D97B0);
  
  // Status Colors
  static const Color online = Color(0xFF43A047);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color urgent = Color(0xFFED6C79);
  static const Color scheduled = Color(0xFF4C87EA);
  
  // Shadow Colors
  static const Color shadowLight = Color(0x0A102149);
  static const Color shadowMedium = Color(0x14102149);
  static const Color shadowDark = Color(0x1E102149);

  // Neumorphic Effects
  static const Color neumorphicLight = Color(0xFFFFFFFF);
  static const Color neumorphicDark = Color(0xFFE5EDF5);
  static const Color neumorphicLightDarkMode = Color(0xFF262F42);
  static const Color neumorphicDarkDarkMode = Color(0xFF1A2133);
  
  // Get text color based on theme mode
  static Color getTextPrimary(bool isDarkMode) => 
      isDarkMode ? textPrimaryDark : textPrimary;
  
  static Color getTextSecondary(bool isDarkMode) => 
      isDarkMode ? textSecondaryDark : textSecondary;
      
  static Color getBackground(bool isDarkMode) => 
      isDarkMode ? backgroundDark : background;
      
  static Color getSurface(bool isDarkMode) => 
      isDarkMode ? surfaceDark1 : surface;
} 