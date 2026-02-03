// lib/app/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Primary brand tone (Gold)
  static const Color primaryColor = Color(0xFFD4AF37);
  static const Color primaryDarker = Color(0xFFC09B30);
  static const Color secondaryColor = Color(0xFF2C2C2C);

  // Soft whites and neutrals that pair beautifully
  static const Color scaffoldLight = Color(0xFFFAFAFA); // A subtle off-white
  static const Color cardLight = Color(0xFFFFFFFF); // Crisp white card for contrast
  static const Color dividerColorLight = Color(0xFFE0E0E0);
  static const Color textDark = Color(0xFF222222);
  static const Color textMedium = Color(0xFF444444);
  static const Color textLight = Color(0xFF757575);

  // Dark theme neutrals
  static const Color scaffoldDark = Color(0xFF101010);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color dividerColorDark = Color(0xFF2A2A2A);
  static const Color textWhite = Color(0xFFF5F5F5);
  static const Color textGrey = Color(0xFFBDBDBD);

  // Helper to generate a consistent MaterialColor from a Color
  static MaterialColor createMaterialColor(Color color) {
    List strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  /// LIGHT THEME
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: false,
    primarySwatch: createMaterialColor(primaryColor),
    primaryColor: primaryColor,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: scaffoldLight, // Softer off-white
    cardColor: cardLight, // Bright white card on soft background
    dividerColor: dividerColorLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffoldLight,
      elevation: 0.5,
      iconTheme: IconThemeData(color: textDark),
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: cardLight,
      background: scaffoldLight,
      onPrimary: Colors.white,
      onSurface: textDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColorLight)),
      focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: primaryColor, width: 1.2)),
    ),
    cardTheme: CardThemeData(
      color: cardLight,
      shadowColor: Colors.black.withOpacity(0.1),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: textDark),
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: textDark),
      bodyLarge: TextStyle(color: textMedium, fontSize: 16.0),
      bodyMedium: TextStyle(color: textLight),
      labelLarge: TextStyle(color: primaryColor),
    ),
  );

  /// DARK THEME
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: false,
    primarySwatch: createMaterialColor(primaryDarker),
    primaryColor: primaryDarker,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: scaffoldDark,
    cardColor: cardDark,
    dividerColor: dividerColorDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: secondaryColor,
      elevation: 0.5,
      iconTheme: IconThemeData(color: primaryDarker),
      titleTextStyle: TextStyle(
        color: primaryColor,
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryDarker,
      secondary: secondaryColor,
      surface: cardDark,
      background: scaffoldDark,
      onPrimary: Colors.black,
      onSurface: textWhite,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDarker,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColorDark)),
      focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: primaryDarker, width: 1.2)),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: textWhite),
      headlineMedium: TextStyle(fontWeight: FontWeight.w600, color: textWhite),
      bodyLarge: TextStyle(color: textGrey, fontSize: 16.0),
      bodyMedium: TextStyle(color: textGrey),
      labelLarge: TextStyle(color: primaryDarker),
    ),
  );
}