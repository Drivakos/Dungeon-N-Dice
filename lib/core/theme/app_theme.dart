import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary palette - Deep fantasy tones
  static const Color parchment = Color(0xFFF4E4BC);
  static const Color parchmentDark = Color(0xFFD4C4A0);
  static const Color inkBlack = Color(0xFF1A1A1A);
  static const Color dragonBlood = Color(0xFF8B0000);
  static const Color dragonGold = Color(0xFFD4AF37);
  static const Color mysticPurple = Color(0xFF4A0E4E);
  static const Color forestGreen = Color(0xFF228B22);
  static const Color arcaneBlue = Color(0xFF1E3A5F);
  
  // Background gradients
  static const Color bgDarkest = Color(0xFF0D0D0D);
  static const Color bgDark = Color(0xFF1A1410);
  static const Color bgMedium = Color(0xFF2D2419);
  static const Color bgLight = Color(0xFF3D3425);
  
  // Accent colors for stats
  static const Color strengthRed = Color(0xFFCC3333);
  static const Color dexterityGreen = Color(0xFF33CC33);
  static const Color constitutionOrange = Color(0xFFCC9933);
  static const Color intelligenceBlue = Color(0xFF3366CC);
  static const Color wisdomSilver = Color(0xFFAAAAAA);
  static const Color charismaGold = Color(0xFFCCAA33);
  
  // UI States
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Border and UI elements
  static const Color borderColor = Color(0xFF4A4030);
  
  // Gradients
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgDark, bgDarkest],
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDarkest,
      
      colorScheme: const ColorScheme.dark(
        primary: AppColors.dragonGold,
        secondary: AppColors.mysticPurple,
        surface: AppColors.bgDark,
        error: AppColors.error,
        onPrimary: AppColors.inkBlack,
        onSecondary: AppColors.parchment,
        onSurface: AppColors.parchment,
        onError: Colors.white,
      ),
      
      textTheme: TextTheme(
        // Display styles - for titles and headers
        displayLarge: GoogleFonts.cinzel(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.dragonGold,
          letterSpacing: 2,
        ),
        displayMedium: GoogleFonts.cinzel(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.dragonGold,
          letterSpacing: 1.5,
        ),
        displaySmall: GoogleFonts.cinzel(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.parchment,
          letterSpacing: 1,
        ),
        
        // Headline styles
        headlineLarge: GoogleFonts.cinzel(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.parchment,
        ),
        headlineMedium: GoogleFonts.cinzel(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.parchment,
        ),
        headlineSmall: GoogleFonts.cinzel(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.parchment,
        ),
        
        // Title styles
        titleLarge: GoogleFonts.spectral(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.parchment,
        ),
        titleMedium: GoogleFonts.spectral(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.parchment,
        ),
        titleSmall: GoogleFonts.spectral(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.parchmentDark,
        ),
        
        // Body styles - for story text
        bodyLarge: GoogleFonts.spectral(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: AppColors.parchment,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.spectral(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.parchment,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.spectral(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.parchmentDark,
          height: 1.4,
        ),
        
        // Label styles
        labelLarge: GoogleFonts.spectral(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.dragonGold,
          letterSpacing: 0.5,
        ),
        labelMedium: GoogleFonts.spectral(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.parchment,
        ),
        labelSmall: GoogleFonts.spectral(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.parchmentDark,
        ),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cinzel(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.dragonGold,
          letterSpacing: 1.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.dragonGold),
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.bgMedium,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.dragonGold, width: 1),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dragonGold,
          foregroundColor: AppColors.inkBlack,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.cinzel(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.dragonGold,
          side: const BorderSide(color: AppColors.dragonGold, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.cinzel(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dragonGold, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dragonGold.withValues(alpha: 0.5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dragonGold, width: 2),
        ),
        hintStyle: GoogleFonts.spectral(
          color: AppColors.parchmentDark.withValues(alpha: 0.6),
          fontSize: 16,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgDark,
        selectedItemColor: AppColors.dragonGold,
        unselectedItemColor: AppColors.parchmentDark,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.cinzel(fontSize: 10),
      ),
      
      dividerTheme: DividerThemeData(
        color: AppColors.dragonGold.withValues(alpha: 0.3),
        thickness: 1,
      ),
      
      iconTheme: const IconThemeData(
        color: AppColors.dragonGold,
        size: 24,
      ),
      
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.dragonGold,
        linearTrackColor: AppColors.bgMedium,
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgMedium,
        contentTextStyle: GoogleFonts.spectral(color: AppColors.parchment),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.dragonGold),
        ),
      ),
    );
  }
}


