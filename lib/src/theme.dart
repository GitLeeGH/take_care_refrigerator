import 'package:flutter/material.dart';

// Coral Table: one quiet canvas and one expressive accent across every screen.
// Legacy names remain aliases so existing screens retain the shared tokens.
const Color primaryGreen = Color(0xFFB74436);
const Color coralAccent = Color(0xFFEA7868);
const Color coralSurface = Color(0xFFFFE8E2);
const Color primaryBlue = primaryGreen;
const Color accentYellow = Color(0xFF66736F);
const Color lightGray = Color(0xFFF6F6F6);
const Color mediumGray = Color(0xFF636363);
const Color darkGray = Color(0xFF252424);
const Color softGreen = Color(0xFFF0F0F0);
const Color warmBorder = Color(0xFFE5E5E5);
const Color warningInk = Color(0xFF8D4A20);
const Color dangerInk = Color(0xFFA23E31);
const Color peachSurface = coralSurface;

const pageHeadingStyle = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.w700,
  letterSpacing: -.7,
  height: 1.25,
  color: darkGray,
);
const sectionHeadingStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  letterSpacing: -.3,
  height: 1.35,
  color: darkGray,
);

final ThemeData appTheme = ThemeData(
  primaryColor: primaryGreen,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryGreen,
    primary: primaryGreen,
    secondary: primaryGreen,
    surface: lightGray,
    onSurface: darkGray,
    onPrimary: Colors.white,
    primaryContainer: coralSurface,
    onPrimaryContainer: darkGray,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF7F7F7),
    surfaceContainer: Color(0xFFF3F3F3),
    surfaceContainerHigh: Color(0xFFEEEEEE),
    surfaceContainerHighest: Color(0xFFE8E8E8),
    surfaceTint: Colors.transparent,
    error: dangerInk,
  ),
  scaffoldBackgroundColor: lightGray,
  dividerColor: warmBorder,
  appBarTheme: const AppBarTheme(
    backgroundColor: lightGray,
    foregroundColor: darkGray,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: 20,
    toolbarHeight: 56,
    titleTextStyle: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
      color: darkGray,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(color: mediumGray, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: warmBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: warmBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryGreen, width: 2),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    titleTextStyle: const TextStyle(
      color: darkGray,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.35,
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: lightGray,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: primaryGreen,
    textColor: darkGray,
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryGreen,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: warmBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    indicatorColor: coralSurface,
    elevation: 0,
    height: 68,
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        size: 24,
        color: states.contains(WidgetState.selected)
            ? primaryGreen
            : mediumGray,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
        letterSpacing: 0,
        color: states.contains(WidgetState.selected)
            ? primaryGreen
            : mediumGray,
      ),
    ),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: primaryGreen,
    unselectedLabelColor: mediumGray,
    indicatorColor: primaryGreen,
    dividerColor: warmBorder,
    labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  ),
  textTheme: const TextTheme(
    headlineMedium: pageHeadingStyle,
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.35,
      color: darkGray,
      letterSpacing: -.4,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: darkGray,
      letterSpacing: -.2,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.45,
      color: darkGray,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: darkGray,
      letterSpacing: 0,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.4,
      color: mediumGray,
      letterSpacing: 0,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: darkGray,
    contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  iconButtonTheme: const IconButtonThemeData(
    style: ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, 48)),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    ),
  ),
  useMaterial3: true,
);
