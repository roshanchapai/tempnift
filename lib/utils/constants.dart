import 'package:flutter/material.dart';

// App Colors
class AppColors {
  // Primary color palette
  static const Color primaryColor = Color(0xFF3A86FF); // Vibrant blue
  static const Color secondaryColor = Color(0xFF8338EC); // Purple accent
  static const Color accentColor = Color(0xFFFF006E); // Pink accent
  
  // Background colors
  static const Color backgroundColor = Color(0xFFF8F9FA); // Light gray background
  static const Color cardColor = Colors.white;
  static const Color surfaceColor = Color(0xFFF1F3F5); // Slightly darker than background
  
  // Text colors
  static const Color primaryTextColor = Color(0xFF212529); // Dark gray for primary text
  static const Color secondaryTextColor = Color(0xFF6C757D); // Medium gray for secondary text
  static const Color lightTextColor = Colors.white;
  
  // Status colors
  static const Color successColor = Color(0xFF28A745); // Green
  static const Color errorColor = Color(0xFFDC3545); // Red
  static const Color warningColor = Color(0xFFFFC107); // Yellow
  static const Color infoColor = Color(0xFF17A2B8); // Blue
  
  // Map colors
  static const Color pickupMarkerColor = Color(0xFF28A745); // Green for pickup
  static const Color destinationMarkerColor = Color(0xFFDC3545); // Red for destination
  static const Color routeColor = Color(0xFF3A86FF); // Blue for route
  
  // Gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFF3A86FF),
    Color(0xFF8338EC),
  ];
  
  // Shadow
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  // Border radius
  static const double borderRadius = 12.0;
  static const double buttonRadius = 8.0;
}

// Text Styles
class AppTextStyles {
  // Heading styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryTextColor,
    letterSpacing: -0.5,
  );
  
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryTextColor,
    letterSpacing: -0.3,
  );
  
  // Body text styles
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryTextColor,
    letterSpacing: 0.1,
  );
  
  static const TextStyle bodyBoldStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryTextColor,
    letterSpacing: 0.1,
  );
  
  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryTextColor,
    letterSpacing: 0.2,
  );
  
  // Button text style
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.lightTextColor,
    letterSpacing: 0.5,
  );
  
  // Input text style
  static const TextStyle inputStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryTextColor,
    letterSpacing: 0.1,
  );
  
  // Hint text style
  static const TextStyle hintStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.secondaryTextColor,
    letterSpacing: 0.1,
  );
}

// Common UI Constants
class AppConstants {
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 16.0;
  static const double defaultRadius = 8.0;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration defaultSplashDuration = Duration(seconds: 2);
}

// User Roles
enum UserRole {
  rider,
  passenger,
}

// String Extensions for Validation
extension StringValidation on String {
  bool get isValidPhone {
    // Allows formats like: 98XXXXXXXX, +97798XXXXXXXX, 97798XXXXXXXX
    final phoneRegExp = RegExp(r'^(\+?977)?[9][0-9]{9}$');
    return phoneRegExp.hasMatch(this);
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primaryColor,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryColor,
        secondary: AppColors.secondaryColor,
        surface: AppColors.surfaceColor,
        background: AppColors.backgroundColor,
        error: AppColors.errorColor,
      ),
      scaffoldBackgroundColor: AppColors.backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.lightTextColor),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.lightTextColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          ),
          textStyle: AppTextStyles.buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.borderRadius),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.borderRadius),
          borderSide: const BorderSide(color: AppColors.errorColor, width: 2),
        ),
        hintStyle: AppTextStyles.hintStyle,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.borderRadius),
        ),
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardColor,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.secondaryTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryTextColor,
        contentTextStyle: const TextStyle(color: AppColors.lightTextColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.borderRadius),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceColor,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
